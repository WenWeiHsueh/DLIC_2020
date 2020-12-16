module convCtrl #(
           parameter LOCAL_IDX_WIDTH = 16,
           parameter IN_BUFFER_SIZE = 16,
           parameter OUT_BUFFER_SIZE = 3,
           parameter F_GEN_IN_ADDR = 0,
           parameter F_READ_IN_ENB = 1,
           parameter F_CONV_RELU_ENB = 2,
           parameter F_WRITE_CONV_ENB = 3,
           parameter F_GEN_CONV_ADDR = 4,
           parameter F_READ_CONV_ENB = 5,
           parameter F_WRITE_POOL_ENB = 6,
           parameter F_WRITE_FLAT_ENB = 7
       )(
           input   wire    clk,
           input   wire    reset,
           output  reg     busy,
           input   wire    ready,

           input   wire    [LOCAL_IDX_WIDTH-1:0] local_idx,
           output  reg     local_idx_rst,

           input   wire    [7:0] row_idx,
           output  reg     row_idx_rst,

           output  reg     [11:0] flags
       );

// FSM states
localparam S_IDLE_0 = 0, S_GEN_IN_ADDR = 1, S_READ_IN = 2, S_CONV_RELU = 3,
           S_WRITE_CONV = 4, S_GEN_CONV_ADDR = 5, S_READ_CONV = 6,
           S_WRITE_POOL = 7, S_WRITE_FLAT = 8, S_FINISH = 9;
localparam S_INIT = 0;

// State Register (S)
reg [10:0] curr_state, next_state;
always @(posedge clk, posedge reset) begin
    if(reset)
        curr_state <= (S_INIT | 1'b1); // S_IDLE_0
    else
        curr_state <= next_state;
end // State Register (S)

// IDLE state transition condition
reg idle_done;
always @(negedge reset) begin
    if(!reset && ready)
        idle_done <= 1;
    else
        idle_done <= 0;
end

// State transition condition
wire gen_in_addr_cont = (local_idx == 1);
wire read_in_done = (local_idx == (3*IN_BUFFER_SIZE + 2));
wire comp_conv_done = (local_idx == (OUT_BUFFER_SIZE + 1));
wire write_conv_done = (local_idx == (2*OUT_BUFFER_SIZE + 1));
wire conv_finish = (row_idx == 64);
wire read_conv_done = (local_idx == 8192 + 2);
wire write_pool_done = (local_idx == 2048);
wire write_flat_done = (local_idx == 2048);

// Next State Logic (C)
always @(*) begin
    next_state = S_INIT;

    case(1'b1) // sythnsize parallel_case

        curr_state[S_IDLE_0]: begin
            if(idle_done)
                next_state[S_GEN_IN_ADDR] = 1'b1;
            else
                next_state[S_IDLE_0] = 1'b1;
        end

        curr_state[S_GEN_IN_ADDR]: begin
            if(gen_in_addr_cont)
                next_state[S_READ_IN] = 1'b1;
            else
                next_state[S_GEN_IN_ADDR] = 1'b1;
        end

        curr_state[S_READ_IN]: begin
            if(read_in_done)
                next_state[S_CONV_RELU] = 1'b1;
            else
                next_state[S_READ_IN] = 1'b1;
        end

        curr_state[S_CONV_RELU]: begin
            if(comp_conv_done)
                next_state[S_WRITE_CONV] = 1'b1;
            else
                next_state[S_CONV_RELU] = 1'b1;
        end

        curr_state[S_WRITE_CONV]: begin
            case({write_conv_done, conv_finish})
                2'b00:
                    next_state[S_WRITE_CONV] = 1'b1;
                2'b10:
                    next_state[S_GEN_IN_ADDR] = 1'b1;
                2'b11:
                    next_state[S_GEN_CONV_ADDR] = 1'b1;
                default:
                    next_state[S_IDLE_0] = 1'b1;
            endcase
        end

        curr_state[S_GEN_CONV_ADDR]: begin
            next_state[S_READ_CONV] = 1'b1;
        end

        curr_state[S_READ_CONV]: begin
            if(read_conv_done)
                next_state[S_WRITE_POOL] = 1'b1;
            else
                next_state[S_READ_CONV] = 1'b1;
        end

        curr_state[S_WRITE_POOL]: begin
            if(write_pool_done)
                next_state[S_WRITE_FLAT] = 1'b1;
            else
                next_state[S_WRITE_POOL] = 1'b1;
        end

        curr_state[S_WRITE_FLAT]: begin
            if(write_flat_done)
                next_state[S_FINISH] = 1'b1;
            else
                next_state[S_WRITE_FLAT] = 1'b1;
        end

        curr_state[S_FINISH]: begin
            next_state[S_FINISH] = 1'b1;
        end

        default: begin
            next_state[S_IDLE_0] = 1'b1;
        end

    endcase
end // Next State Logic (C)

// Output Logic (C)
always @(*) begin
    flags = 12'h000;
    local_idx_rst = 0;
    row_idx_rst = 0;
    busy = 1;

    case(1'b1) // sythnsize parallel_case

        curr_state[S_IDLE_0]: begin
            local_idx_rst = 1;
            row_idx_rst = 1;
            busy = 0;
        end

        curr_state[S_GEN_IN_ADDR]: begin
            flags[F_GEN_IN_ADDR] = 1'b1;
        end

        curr_state[S_READ_IN]: begin
            if(read_in_done) begin
                local_idx_rst = 1;
            end
            else begin
                flags[F_READ_IN_ENB] = 1'b1;
                flags[F_GEN_IN_ADDR] = 1'b1;
            end
        end

        curr_state[S_CONV_RELU]: begin
            if(comp_conv_done)
                local_idx_rst = 1;
            else
                flags[F_CONV_RELU_ENB] = 1'b1;
        end

        curr_state[S_WRITE_CONV]: begin
            if(write_conv_done)
                local_idx_rst = 1;
            else
                flags[F_WRITE_CONV_ENB] = 1'b1;
        end

        curr_state[S_GEN_CONV_ADDR]: begin
            flags[F_GEN_CONV_ADDR] = 1'b1;
        end

        curr_state[S_READ_CONV]: begin
            if(read_conv_done)
                local_idx_rst = 1;
            else begin
                flags[F_READ_CONV_ENB] = 1'b1;
                flags[F_GEN_CONV_ADDR] = 1'b1;
            end
        end

        curr_state[S_WRITE_POOL]: begin
            if(write_pool_done)
                local_idx_rst = 1;
            else
                flags[F_WRITE_POOL_ENB] = 1'b1;
        end

        curr_state[S_WRITE_FLAT]: begin
            if(write_flat_done)
                local_idx_rst = 1;
            else
                flags[F_WRITE_FLAT_ENB] = 1'b1;
        end

        curr_state[S_FINISH]:
            busy = 0;

        default:
            busy = 0;

    endcase
end // Output Logic (C)

endmodule
