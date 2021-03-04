`include "def.v"

module convDataPath (
           input   wire    clk,

           output  wire    [11:0] iaddr,
           input   wire    [`DATA_WIDTH-1:0] idata,

           output  reg     cwr,
           output  reg     [11:0] caddr_wr,
           output  reg     [`DATA_WIDTH-1:0] cdata_wr,

           output  reg     crd,
           output  reg     [11:0] caddr_rd,
           input   wire    [`DATA_WIDTH-1:0] cdata_rd,

           output  reg     [2:0] csel,

           input   wire    [`FLAG_WIDTH-1:0] flags,
           input   wire    [`LOCAL_IDX_WIDTH-1:0] local_idx,
           input   wire    [7:0] row_idx
       );

// kernel weight 0 (hardcode)
wire signed [`DATA_WIDTH-1:0] w_mem0 [0:8];
assign w_mem0[0] = 20'h0A89E;
assign w_mem0[1] = 20'h092D5;
assign w_mem0[2] = 20'h06D43;
assign w_mem0[3] = 20'h01004;
assign w_mem0[4] = 20'hF8F71;
assign w_mem0[5] = 20'hF6E54;
assign w_mem0[6] = 20'hFA6D7;
assign w_mem0[7] = 20'hFC834;
assign w_mem0[8] = 20'hFAC19;
// bias 0 (hardcode)
wire signed [`DATA_WIDTH-1:0] b_0 = 20'h01310;
// kernel weight 1 (hardcode)
wire signed [`DATA_WIDTH-1:0] w_mem1 [0:8];
assign w_mem1[0] = 20'hFDB55;
assign w_mem1[1] = 20'h02992;
assign w_mem1[2] = 20'hFC994;
assign w_mem1[3] = 20'h050FD;
assign w_mem1[4] = 20'h02F20;
assign w_mem1[5] = 20'h0202D;
assign w_mem1[6] = 20'h03BD7;
assign w_mem1[7] = 20'hFD369;
assign w_mem1[8] = 20'h05E68;
// bias 1 (hardcode)
wire signed [`DATA_WIDTH-1:0] b_1 = 20'hF7295;

// Input memory (Stores input data)
reg signed [`DATA_WIDTH-1:0] in_mem0 [0:`IN_BUFFER_SIZE-1];
reg signed [`DATA_WIDTH-1:0] in_mem1 [0:`IN_BUFFER_SIZE-1];
reg signed [`DATA_WIDTH-1:0] in_mem2 [0:`IN_BUFFER_SIZE-1];

// Output memory (Stores the results of convolution)
wire signed [2*`DATA_WIDTH-1:0] conv_out_raw [0:5]; // Output of 6 PE units
reg signed [`DATA_WIDTH-1:0] conv_out_fifo_ker0 [0:`OUT_BUFFER_SIZE-1]; // Output of kernel 0
reg signed [`DATA_WIDTH-1:0] conv_out_fifo_ker1 [0:`OUT_BUFFER_SIZE-1]; // Output of kernel 1

// pseudo_addr is the address for fake memory
reg [`LOCAL_IDX_WIDTH-1:0] pseudo_addr;

// Generate input address
wire [`LOCAL_IDX_WIDTH-1:0] in_row_offset = row_idx * 66;
wire addr0_sel = (local_idx < `IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
wire addr1_sel = (local_idx >= `IN_BUFFER_SIZE && local_idx < 2*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
wire addr2_sel = (local_idx >= 2*`IN_BUFFER_SIZE && local_idx < 3*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
always @(posedge clk) begin
    if(flags[`F_GEN_IN_ADDR]) begin
        case({addr0_sel, addr1_sel, addr2_sel}) //synopsys full_case
            3'b100:
                pseudo_addr <= in_row_offset + local_idx;
            3'b010:
                pseudo_addr <= in_row_offset + local_idx - `IN_BUFFER_SIZE + 66;
            3'b001:
                pseudo_addr <= in_row_offset + local_idx - 2*`IN_BUFFER_SIZE + 132;
        endcase
    end
end

// Pseudo memory that mimic the behavior of zero-padded input feature map
wire in_zero_flag;
fakeMem f_mem (
            .clk(clk), 
            .pseudo_addr(pseudo_addr),
            .iaddr(iaddr), 
            .zero_flag(in_zero_flag)
        );

// Synchronize the async idata signal
reg [`DATA_WIDTH-1:0] idata_sync;
always @(posedge clk) begin
    idata_sync <= (in_zero_flag == 1) ? 0 : idata;
end

// Get input data OR push FIFO into PE
// Get input data
wire [7:0] read_in_idx = (local_idx >= `READ_MEM_DELAY) ? (local_idx - `READ_MEM_DELAY) : 0;
wire m0_sel = (read_in_idx < `IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
wire m1_sel = (read_in_idx >= `IN_BUFFER_SIZE && read_in_idx < 2*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
wire m2_sel = (read_in_idx >= 2*`IN_BUFFER_SIZE && read_in_idx < 3*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
// Push FIFO into PE
reg signed [7:0] feed_in_idx;
always @(posedge clk) begin
    case({flags[`F_READ_IN_ENB], flags[`F_CONV_RELU_ENB]}) //synopsys full_case
        2'b10: begin
            case({m0_sel, m1_sel, m2_sel}) //synopsys full_case
                3'b100:
                    in_mem0[read_in_idx] <= idata_sync;
                3'b010:
                    in_mem1[read_in_idx - `IN_BUFFER_SIZE] <= idata_sync;
                3'b001:
                    in_mem2[read_in_idx - 2*`IN_BUFFER_SIZE] <= idata_sync;
            endcase
        end

        2'b01: begin
            for(feed_in_idx=0 ; feed_in_idx < `IN_BUFFER_SIZE-1 ; feed_in_idx = feed_in_idx + 1) begin
                in_mem0[feed_in_idx] <= in_mem0[feed_in_idx+1];
                in_mem1[feed_in_idx] <= in_mem1[feed_in_idx+1];
                in_mem2[feed_in_idx] <= in_mem2[feed_in_idx+1];
            end
        end
    endcase
end

// 1D convolution unit
wire mul_enb = flags[`F_CONV_RELU_ENB];
// Kernel 0
PE_1d pe_0 (
          .clk(clk), .enb(mul_enb),
          .f0(w_mem0[0]), .f1(w_mem0[1]), .f2(w_mem0[2]),
          .in0(in_mem0[0]), .in1(in_mem0[1]), .in2(in_mem0[2]),
          .out_reg(conv_out_raw[0]));

PE_1d pe_1 (
          .clk(clk), .enb(mul_enb),
          .f0(w_mem0[3]), .f1(w_mem0[4]), .f2(w_mem0[5]),
          .in0(in_mem1[0]), .in1(in_mem1[1]), .in2(in_mem1[2]),
          .out_reg(conv_out_raw[1]));

PE_1d pe_2 (
          .clk(clk), .enb(mul_enb),
          .f0(w_mem0[6]), .f1(w_mem0[7]), .f2(w_mem0[8]),
          .in0(in_mem2[0]), .in1(in_mem2[1]), .in2(in_mem2[2]),
          .out_reg(conv_out_raw[2]));

// Kernel 1
PE_1d pe_3 (
          .clk(clk), .enb(mul_enb),
          .f0(w_mem1[0]), .f1(w_mem1[1]), .f2(w_mem1[2]),
          .in0(in_mem0[0]), .in1(in_mem0[1]), .in2(in_mem0[2]),
          .out_reg(conv_out_raw[3]));

PE_1d pe_4 (
          .clk(clk), .enb(mul_enb),
          .f0(w_mem1[3]), .f1(w_mem1[4]), .f2(w_mem1[5]),
          .in0(in_mem1[0]), .in1(in_mem1[1]), .in2(in_mem1[2]),
          .out_reg(conv_out_raw[4]));

PE_1d pe_5 (
          .clk(clk), .enb(mul_enb),
          .f0(w_mem1[6]), .f1(w_mem1[7]), .f2(w_mem1[8]),
          .in0(in_mem2[0]), .in1(in_mem2[1]), .in2(in_mem2[2]),
          .out_reg(conv_out_raw[5]));

// Compute partial sum of 3 rows of kernel 0 and kernel 1
wire signed [2*`DATA_WIDTH-1:0] p_sum_raw [0:1];
assign p_sum_raw[0] = conv_out_raw[0] + conv_out_raw[1] + conv_out_raw[2]; // kernel 0
assign p_sum_raw[1] = conv_out_raw[3] + conv_out_raw[4] + conv_out_raw[5]; // kernel 1

// Compute rounding partial sum
wire signed [`DATA_WIDTH-1:0] sum [0:1];
assign sum[0] = p_sum_raw[0][2*`DATA_WIDTH-5:`DATA_WIDTH-4] + p_sum_raw[0][`DATA_WIDTH-5] + b_0; // kernel 0
assign sum[1] = p_sum_raw[1][2*`DATA_WIDTH-5:`DATA_WIDTH-4] + p_sum_raw[1][`DATA_WIDTH-5] + b_1; // kernel 1

// Compute ReLU
wire signed [`DATA_WIDTH-1:0] relu_out [0:1];
assign relu_out[0] = (sum[0][`DATA_WIDTH-1] == 1'b1) ? 0 : sum[0];
assign relu_out[1] = (sum[1][`DATA_WIDTH-1] == 1'b1) ? 0 : sum[1];

// Convolution output FIFO
reg signed [7:0] out_idx;
always @(posedge clk) begin
    if(flags[`F_CONV_RELU_ENB]) begin
        if(local_idx >= 2) begin
            // Push the results to the bottom of the FIFO
            conv_out_fifo_ker0[`OUT_BUFFER_SIZE-1] <= relu_out[0];
            conv_out_fifo_ker1[`OUT_BUFFER_SIZE-1] <= relu_out[1];

            for(out_idx = `OUT_BUFFER_SIZE-2 ; out_idx >= 0 ; out_idx = out_idx - 1) begin
                conv_out_fifo_ker0[out_idx] <= conv_out_fifo_ker0[out_idx+1];
                conv_out_fifo_ker1[out_idx] <= conv_out_fifo_ker1[out_idx+1];
            end
        end
    end
end

// Read from Layer 0
reg [`DATA_WIDTH-1:0] layer0_ker0_mem [0:4095];
reg [`DATA_WIDTH-1:0] layer0_ker1_mem [0:4095];

// Synchronize the async signal cdata_rd
reg [`DATA_WIDTH-1:0] cdata_rd_sync;
always @(posedge clk) begin
    cdata_rd_sync <= cdata_rd;
end

// Read from Layer 0
wire [12:0] read_layer0_idx = (local_idx >= `READ_MEM_DELAY) ? (local_idx - `READ_MEM_DELAY) : 13'b0;
wire [0:1] conv_mem_sel = {(read_layer0_idx < 4096) ? 1'b1 : 1'b0, (read_layer0_idx >= 4096 && read_layer0_idx < 2*4096) ? 1'b1 : 1'b0};
always @(posedge clk) begin
    if(flags[`F_READ_CONV_ENB]) begin
        case(conv_mem_sel) //synopsys full_case
            2'b10: begin
                layer0_ker0_mem[read_layer0_idx] <= cdata_rd_sync;
            end
            2'b01: begin
                layer0_ker1_mem[read_layer0_idx - 4096] <= cdata_rd_sync;
            end
        endcase
    end
end

// Pooling
wire [`DATA_WIDTH-1:0] max_pool_ker0 [0:1023];
wire [`DATA_WIDTH-1:0] max_pool_ker1 [0:1023];
genvar i, j;
generate
    for(i=0;i<32;i=i+1) begin: rowBlock // row
        for(j=0;j<32;j=j+1) begin: colBlock // col
            // Pooling units for kernel 0 results
            maxPool_2x2 p_0 (
                            .in0(layer0_ker0_mem[i * 128 + j * 2]),
                            .in1(layer0_ker0_mem[i * 128 + j * 2 + 1]),
                            .in2(layer0_ker0_mem[i * 128 + j * 2 + 64]),
                            .in3(layer0_ker0_mem[i * 128 + j * 2 + 65]),
                            .max(max_pool_ker0[i * 32 + j])
                        );
            // Pooling units for kernel 1 results
            maxPool_2x2 p_1 (
                            .in0(layer0_ker1_mem[i * 128 + j * 2]),
                            .in1(layer0_ker1_mem[i * 128 + j * 2 + 1]),
                            .in2(layer0_ker1_mem[i * 128 + j * 2 + 64]),
                            .in3(layer0_ker1_mem[i * 128 + j * 2 + 65]),
                            .max(max_pool_ker1[i * 32 + j])
                        );
        end
    end
endgenerate

// csel / cwr / caddr_wr / cdata_wr / crd / caddr_rd signals for memory RW //

// Write the convolution results to Layer 0
wire [`LOCAL_IDX_WIDTH-1:0] out_row_offset = row_idx * 64;
wire [7:0] conv_out_idx = local_idx;
wire [0:1] wr_conv_sel = {(conv_out_idx < `OUT_BUFFER_SIZE) ? 1'b1 : 1'b0, (conv_out_idx >= `OUT_BUFFER_SIZE && conv_out_idx < 2*`OUT_BUFFER_SIZE) ? 1'b1 : 1'b0};

// Generate read address to Layer 0
wire [0:1] layer0_addr_sel = {(local_idx < 4096) ? 1'b1 : 1'b0, (local_idx >= 4096 && local_idx < 2*4096) ? 1'b1 : 1'b0};

// Write pooling results
wire [0:1] pool_mem_sel = {(local_idx < 1024) ? 1'b1 : 1'b0, (local_idx >= 1024 && local_idx < 2*1024) ? 1'b1 : 1'b0};
wire [10:0] max_pool_idx = local_idx;

// Write flattening results
wire [0:1] flat_mem_sel = {(local_idx < 1024) ? 1'b1 : 1'b0, (local_idx >= 1024 && local_idx < 2*1024) ? 1'b1 : 1'b0};
wire [`LOCAL_IDX_WIDTH-1:0] double_local_idx = {local_idx[`LOCAL_IDX_WIDTH-2:0], 1'b0};

always @(posedge clk) begin
    case({flags[`F_WRITE_CONV_ENB], flags[`F_GEN_CONV_ADDR], flags[`F_WRITE_POOL_ENB], flags[`F_WRITE_FLAT_ENB]}) //synopsys full_case
        
        // flags[`F_WRITE_CONV_ENB]
        4'b1000: begin
            case(wr_conv_sel) //synopsys full_case
                2'b10: begin // Write kernel 0 conv result to Layer 0
                    cwr <= 1'b1;
                    csel <= 3'b001;
                    caddr_wr <= out_row_offset + conv_out_idx;
                    cdata_wr <= conv_out_fifo_ker0[conv_out_idx];
                end
                2'b01: begin // Write kernel 1 conv result to Layer 0
                    cwr <= 1'b1;
                    csel <= 3'b010;
                    caddr_wr <= out_row_offset + (conv_out_idx - `OUT_BUFFER_SIZE);
                    cdata_wr <= conv_out_fifo_ker1[conv_out_idx - `OUT_BUFFER_SIZE];
                end
                2'b00: begin
                    cwr <= 1'b0;
                    csel <= 3'b000;
                    caddr_wr <= `EMPTY_ADDR;
                    cdata_wr <= `EMPTY_DATA;
                end
            endcase
            caddr_rd <= `EMPTY_ADDR;
            crd <= 1'b0; 
        end
        
        // flags[`F_GEN_CONV_ADDR]
        4'b0100: begin
            case(layer0_addr_sel) //synopsys full_case
                2'b10: begin // Read layer 0 results computed by kernel 0
                    crd <= 1'b1;
                    csel <= 3'b001;
                    caddr_rd <= local_idx;
                end
                2'b01: begin // Read layer 0 results computed by kernel 1
                    crd <= 1'b1;
                    csel <= 3'b010;
                    caddr_rd <= (local_idx - 4096);
                end
                2'b00: begin
                    crd <= 1'b0;
                    csel <= 3'b000;
                    caddr_rd <= `EMPTY_ADDR;
                end
            endcase
            caddr_wr <= `EMPTY_ADDR;
            cdata_wr <= `EMPTY_DATA;
            cwr <= 1'b0; 
        end

        // flags[`F_WRITE_POOL_ENB]
        4'b0010: begin
            case(pool_mem_sel) //synopsys full_case
                2'b10: begin // Write pooling results computed by kernel 0
                    cwr <= 1'b1;
                    csel <= 3'b011;
                    caddr_wr <= local_idx;
                    cdata_wr <= max_pool_ker0[max_pool_idx];    
                end
                2'b01: begin // Write pooling results computed by kernel 1
                    cwr <= 1'b1;
                    csel <= 3'b100;
                    caddr_wr <= (local_idx - 1024);
                    cdata_wr <= max_pool_ker1[max_pool_idx - 1024];
                end
                2'b00: begin
                    cwr <= 1'b0;
                    csel <= 3'b000;                
                    caddr_wr <= `EMPTY_ADDR;
                    cdata_wr <= `EMPTY_DATA;
                end
            endcase
            caddr_rd <= `EMPTY_ADDR;
            crd <= 1'b0; 
        end

        // flags[`F_WRITE_FLAT_ENB]
        4'b0001: begin
            case(flat_mem_sel) //synopsys full_case
                2'b10: begin // Write kernel 0 pooling results to even address
                    cwr <= 1'b1;
                    csel <= 3'b101; // Write to layer 2 (flattening layer)
                    caddr_wr <= double_local_idx;
                    cdata_wr <= max_pool_ker0[max_pool_idx];
                end
                2'b01: begin // Write kernel 1 pooling results to odd address
                    cwr <= 1'b1;
                    csel <= 3'b101; // Write to layer 2 (flattening layer)
                    caddr_wr <= (double_local_idx - 2*1024 + 1);
                    cdata_wr <= max_pool_ker1[max_pool_idx - 1024];
                end
                2'b00: begin
                    cwr <= 1'b0;
                    csel <= 3'b000;                
                    caddr_wr <= `EMPTY_ADDR;
                    cdata_wr <= `EMPTY_DATA;
                end
            endcase
            caddr_rd <= `EMPTY_ADDR;
            crd <= 1'b0; 
        end

    endcase
    
end       

endmodule
