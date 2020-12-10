module conv(
           clk,
           rst,
           M0_R_req,
           M0_W_req,
           M0_addr,
           M0_R_data,
           M0_W_data,
           M1_R_req,
           M1_W_req,
           M1_addr,
           M1_R_data,
           M1_W_data,
           start,
           finish
       );
// Read from M0 cell, write to M1 cell
input clk, rst, start;
input wire [31:0] M0_R_data, M1_R_data;
output reg finish;
output reg [31:0] M0_addr;
output reg [31:0] M1_addr;
output reg M0_R_req;
output reg M1_R_req;
output reg [3:0] M0_W_req;
output reg [3:0] M1_W_req;
output reg [31:0] M0_W_data;
output reg [31:0] M1_W_data;

// Local index iterator
reg [9:0] local_idx = 10'h000;
reg local_idx_rst = 0;

// Global index iterator
reg [11:0] global_idx = 12'h000;
reg global_idx_rst = 0;

// Internal memory
reg [15:0] input_mem [0:8];
reg signed [31:0] weight_mem_signed [0:9];

// FSM state
localparam S_READY = 0, S_READ_WEIGHT = 1, S_READ_INPUT = 2, S_MULTIPLY = 3, S_ADD = 4, S_WRITE = 5, S_FINISH = 6;
localparam [6:0] INIT_S = 7'h00;
reg [6:0] curr_state;
reg [6:0] next_state = INIT_S;

// State register (S)
always @(posedge clk) begin
    if(!rst)
        curr_state <= INIT_S;
    else
        curr_state <= next_state;
end

// Next state logic (C)
wire read_w_done = (local_idx == 12);
wire read_in_done = (local_idx == 11);
wire mul_done = (local_idx == 9);
wire add_done = (local_idx == 3);
wire write_done = (local_idx == 1);
wire finish_cond = (global_idx == 676);
reg gen_read_w_addr_sig = 0, gen_read_in_addr_sig = 0, write_enb = 0, mult_enb = 0, add_enb = 0;
reg add_rst = 0, mul_rst = 0;
always @(*) begin
    next_state = INIT_S;

    case(1'b1) // synthesis parallel_case

        curr_state[S_READY]: begin
            if(start == 1)
                next_state[S_READ_WEIGHT] = 1'b1;
            else
                next_state[S_READY] = 1'b1;
        end

        curr_state[S_READ_WEIGHT]: begin
            if(read_w_done)
                next_state[S_READ_INPUT] = 1'b1;
            else
                next_state[S_READ_WEIGHT] = 1'b1;
        end

        curr_state[S_READ_INPUT]: begin
            if(read_in_done)
                next_state[S_MULTIPLY] = 1'b1;
            else
                next_state[S_READ_INPUT] = 1'b1;
        end

        curr_state[S_MULTIPLY]: begin
            if(mul_done)
                next_state[S_ADD] = 1'b1;
            else
                next_state[S_MULTIPLY] = 1'b1;
        end

        curr_state[S_ADD]: begin
            if(add_done)
                next_state[S_WRITE] = 1'b1;
            else
                next_state[S_ADD] = 1'b1;
        end

        curr_state[S_WRITE]: begin
            case({write_done, finish_cond})
                2'b00:
                    next_state[S_WRITE] = 1'b1;
                2'b10:
                    next_state[S_READ_INPUT] = 1'b1;
                2'b11:
                    next_state[S_FINISH] = 1'b1;
                default:
                    next_state[S_FINISH] = 1'b1;
            endcase
        end

        curr_state[S_FINISH]: begin
            next_state[S_FINISH] = 1'b1;
        end

        default: begin
            next_state[S_READY] = 1'b1;
        end
    endcase
end

// Output logic (C)
always @(*) begin
    global_idx_rst = 0;
    local_idx_rst = 0;
    finish = 0;
    gen_read_w_addr_sig = 0;
    gen_read_in_addr_sig = 0;
    write_enb = 0;
    mult_enb = 0;
    mul_rst = 0;
    add_enb = 0;
    add_rst = 0;

    case(1'b1) // synthesis parallel_case

        curr_state[S_READY]: begin
            if(start == 1) begin
                global_idx_rst = 1;
                local_idx_rst = 1;
            end
        end

        curr_state[S_READ_WEIGHT]: begin
            if(read_w_done)
                local_idx_rst = 1;
            else
                gen_read_w_addr_sig = 1;
        end

        curr_state[S_READ_INPUT]: begin
            if(read_in_done) begin
                local_idx_rst = 1;
                mul_rst = 1;
            end
            else
                gen_read_in_addr_sig = 1;
        end

        curr_state[S_MULTIPLY]: begin
            if(mul_done) begin
                local_idx_rst = 1;
                add_rst = 1;
            end
            else
                mult_enb = 1;
        end

        curr_state[S_ADD]: begin
            if(add_done)
                local_idx_rst = 1;
            else
                add_enb = 1;
        end

        curr_state[S_WRITE]: begin
            case({write_done, finish_cond})
                2'b00:
                    write_enb = 1;
                2'b10:
                    local_idx_rst = 1;
                default:
                    ;
            endcase
        end

        curr_state[S_FINISH]:
            finish = 1;

        default:
            ;
    endcase
end


reg read_in_enb = 0;
reg [7:0] block_offset = 8'h00;
wire [7:0] block_offset_next = block_offset + 1;
// Triggered by read_in_enb
always @(posedge clk) begin // Generating read input sequence 0-1-2-28-29-30-56-57-58
    if(read_in_enb == 1)
        if(block_offset == 2)
            block_offset <= 28;
        else if(block_offset == 30)
            block_offset <= 56;
        else
            block_offset <= block_offset_next;
    else
        block_offset <= 0;
end

// Triggered by gen_read_w_addr_sig and gen_read_in_addr_sig
wire [31:0] void_data = 32'h00C0FFEE;
wire [27:0] mod26_mul = global_idx * 16'h09D9;
wire [7:0] row_offset = {mod26_mul[22:16], 1'b0}; // global_idx % 26
wire [11:0] idx = global_idx + block_offset + row_offset;
reg read_w_enb = 0;
always @(posedge clk) begin // Generate read request and read address to M0 BRAM

    case( {gen_read_w_addr_sig, gen_read_in_addr_sig} )
        2'b10: begin
            M0_R_req <= 1;
            M0_W_req <= 4'b0000;
            M0_addr <= 32'hc40 + {20'h0, local_idx, 2'b00};
            read_w_enb <= 1;
            read_in_enb <= 0;
        end
        2'b01: begin
            M0_R_req <= 1;
            M0_W_req <= 4'b0000;
            M0_addr <= {18'h0, idx, 2'b00};
            read_w_enb <= 0;
            read_in_enb <= 1;
            if(global_idx==89) begin
                M0_R_req <= 1;
                M0_W_req <= 4'b0000;
                M0_addr <= {18'h0, idx, 2'b00};
                read_w_enb <= 0;
                read_in_enb <= 1;
            end
        end
        default: begin
            M0_R_req <= 0;
            M0_W_req <= 4'b0000;
            M0_addr <= void_data;
            read_w_enb <= 0;
            read_in_enb <= 0;
        end
    endcase
end

// Triggered by read_w_enb and read_in_enb
wire [9:0] weight_mem_r_idx = (local_idx > 1) ? (local_idx-2) : 0;
wire [9:0] input_mem_r_idx = (local_idx > 2) ? (local_idx-3) : 0;
always @(posedge clk) begin // Read weight and input
    case({read_w_enb, read_in_enb})
        2'b10:
            weight_mem_signed[weight_mem_r_idx] <= M0_R_data;
        2'b01:
            input_mem[input_mem_r_idx] <= M0_R_data[15:0];
        default:
            ;
    endcase
end

// Triggered by mult_enb
wire [3:0] mul_idx = local_idx[3:0];
reg signed [47:0] mul_48 [0:8];
wire signed [31:0] input_mem_signed_ext [8:0];

assign input_mem_signed_ext[0] = {{16{1'b0}}, input_mem[0]};
assign input_mem_signed_ext[1] = {{16{1'b0}}, input_mem[1]};
assign input_mem_signed_ext[2] = {{16{1'b0}}, input_mem[2]};
assign input_mem_signed_ext[3] = {{16{1'b0}}, input_mem[3]};
assign input_mem_signed_ext[4] = {{16{1'b0}}, input_mem[4]};
assign input_mem_signed_ext[5] = {{16{1'b0}}, input_mem[5]};
assign input_mem_signed_ext[6] = {{16{1'b0}}, input_mem[6]};
assign input_mem_signed_ext[7] = {{16{1'b0}}, input_mem[7]};
assign input_mem_signed_ext[8] = {{16{1'b0}}, input_mem[8]};

integer j;
wire signed [47:0] mul_48_0 = weight_mem_signed[0] * input_mem_signed_ext[0];
wire signed [47:0] mul_48_1 = weight_mem_signed[1] * input_mem_signed_ext[1];
wire signed [47:0] mul_48_2 = weight_mem_signed[2] * input_mem_signed_ext[2];
wire signed [47:0] mul_48_3 = weight_mem_signed[3] * input_mem_signed_ext[3];
wire signed [47:0] mul_48_4 = weight_mem_signed[4] * input_mem_signed_ext[4];
wire signed [47:0] mul_48_5 = weight_mem_signed[5] * input_mem_signed_ext[5];
wire signed [47:0] mul_48_6 = weight_mem_signed[6] * input_mem_signed_ext[6];
wire signed [47:0] mul_48_7 = weight_mem_signed[7] * input_mem_signed_ext[7];
wire signed [47:0] mul_48_8 = weight_mem_signed[8] * input_mem_signed_ext[8];

always @(posedge clk) begin // Compute multiply results and stores in 48 bits
    if(mul_rst == 1) begin
        for(j=0;j<=8;j=j+1) begin
            mul_48[j] <= 48'h0;
        end
    end
    else if (mult_enb==1) begin
        case(mul_idx)
            4'h0:
                mul_48[0] <= (mult_enb == 1) ? mul_48_0 : mul_48[0];
            4'h1:
                mul_48[1] <= (mult_enb == 1) ? mul_48_1 : mul_48[1];
            4'h2:
                mul_48[2] <= (mult_enb == 1) ? mul_48_2 : mul_48[2];
            4'h3:
                mul_48[3] <= (mult_enb == 1) ? mul_48_3 : mul_48[3];
            4'h4:
                mul_48[4] <= (mult_enb == 1) ? mul_48_4 : mul_48[4];
            4'h5:
                mul_48[5] <= (mult_enb == 1) ? mul_48_5 : mul_48[5];
            4'h6:
                mul_48[6] <= (mult_enb == 1) ? mul_48_6 : mul_48[6];
            4'h7:
                mul_48[7] <= (mult_enb == 1) ? mul_48_7 : mul_48[7];
            4'h8:
                mul_48[8] <= (mult_enb == 1) ? mul_48_8 : mul_48[8];
            default:
                ;
        endcase
    end
end

// Round off 48 bits results to 32 bits
reg signed [31:0] mul_32 [0:8];
integer i;
always @(*) begin
    for(i=0;i<=8;i=i+1) begin
        mul_32[i] <= mul_48[i][47:16] + mul_48[i][15];
    end
end

// Triggered by add_enb
reg signed [31:0] partial_sum_1 [0:4]; // first level adder
reg signed [31:0] partial_sum_2 [0:2]; // second level adder
reg signed [31:0] res; // final result
integer k, m;
wire [1:0] add_idx = local_idx[1:0];
always @(posedge clk) begin // Compute add results
    if(add_rst == 1) begin
        for(k=0 ; k<=4 ; k=k+1) begin
            partial_sum_1[k] <= void_data;
        end
        for(m=0 ; m<=2 ; m=m+1) begin
            partial_sum_2[m] <= void_data;
        end
        res <= void_data;
    end
    else if(add_enb == 1) begin
        case(add_idx)
            2'b00: begin
                partial_sum_1[0] <= (add_enb == 1) ? (mul_32[0] + mul_32[1]) : partial_sum_1[0];
                partial_sum_1[1] <= (add_enb == 1) ? (mul_32[2] + mul_32[3]) : partial_sum_1[1];
                partial_sum_1[2] <= (add_enb == 1) ? (mul_32[4] + mul_32[5]) : partial_sum_1[2];
                partial_sum_1[3] <= (add_enb == 1) ? (mul_32[6] + mul_32[7]) : partial_sum_1[3];
                partial_sum_1[4] <= (add_enb == 1) ? (mul_32[8] + weight_mem_signed[9]) : partial_sum_1[4];
            end
            2'b01: begin
                partial_sum_2[0] <= (add_enb == 1) ? (partial_sum_1[0] + partial_sum_1[1]) : partial_sum_2[0];
                partial_sum_2[1] <= (add_enb == 1) ? (partial_sum_1[2] + partial_sum_1[3]) : partial_sum_2[1];
                partial_sum_2[2] <= (add_enb == 1) ? partial_sum_1[4] : partial_sum_2[2];
            end
            2'b10: begin
                res <= (add_enb == 1) ? (partial_sum_2[0] + partial_sum_2[1] + partial_sum_2[2]) : void_data;
            end
            default:
                ;
        endcase
    end
end

// Triggered by write_enb
always @(posedge clk) begin // Write conv results

    if(write_enb == 1) begin
        M1_W_req <= 4'b1111;
        M1_R_req <= 1;
        M1_addr <= {18'b0, global_idx, 2'b0};
        M1_W_data <= res;
    end
    else begin
        M1_W_req <= 4'b0000;
        M1_R_req <= 0;
        M1_addr <= void_data;
        M1_W_data <= void_data;
    end
end

// Triggered by local_idx_rst
wire [9:0] local_idx_next = local_idx + 1;
always @(posedge clk) begin // Local index iterator
    if(local_idx_rst == 1)
        local_idx <= 0;
    else
        local_idx <= local_idx_next;
end

// Triggered by write_enb
wire [11:0] global_idx_next = global_idx + 1;
always @(posedge clk) begin // Global index iteratorx
    if(global_idx_rst == 1)
        global_idx <= 12'h0;
    else
        global_idx <= ((write_enb == 1) ? global_idx_next : global_idx);
end

endmodule
