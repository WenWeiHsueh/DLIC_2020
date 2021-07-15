`include "def.v"

module dp (
  input                                 clk,
  input                                 reset,
  
  output                          [11:0] iaddr,
  input                [`DATA_WIDTH-1:0] idata,
  
  output reg                             cwr,
  output reg                      [11:0] caddr_wr,
  output reg           [`DATA_WIDTH-1:0] cdata_wr,
  
  output reg                             crd,
  output reg                      [11:0] caddr_rd,
  input                [`DATA_WIDTH-1:0] cdata_rd,
  
  output reg                       [2:0] csel,
  
  input                [`FLAG_WIDTH-1:0] flags,
  input           [`LOCAL_IDX_WIDTH-1:0] local_idx,
  input                            [7:0] row_idx
);

  // Include kernel weights
  `include "weight.param"

  // Input memory (Stores input data)
  reg signed           [`DATA_WIDTH-1:0] in_mem0 [0:`IN_BUFFER_SIZE-1];
  reg signed           [`DATA_WIDTH-1:0] in_mem1 [0:`IN_BUFFER_SIZE-1];
  reg signed           [`DATA_WIDTH-1:0] in_mem2 [0:`IN_BUFFER_SIZE-1];

  // Output memory (Stores the results of convolution)
    // Output of 6 PE units
  wire signed        [2*`DATA_WIDTH-1:0] conv_out_raw [0:5]; 
    // Output of kernel 0
  reg signed           [`DATA_WIDTH-1:0] conv_out_fifo_ker0 [0:`OUT_BUFFER_SIZE-1];
    // Output of kernel 1
  reg signed           [`DATA_WIDTH-1:0] conv_out_fifo_ker1 [0:`OUT_BUFFER_SIZE-1];

  // pseudo_addr is the address for fake memory
  reg             [`LOCAL_IDX_WIDTH-1:0] pseudo_addr;

  // Other
  wire            [`LOCAL_IDX_WIDTH-1:0] in_row_offset;
  wire                                   addr0_sel, addr1_sel, addr2_sel;
  wire                                   m0_sel, m1_selm, m2_sel;
  wire                             [7:0] read_in_idx;
  wire                                   mul_enb;
  wire signed        [2*`DATA_WIDTH-1:0] p_sum_raw [0:1];
  wire signed          [`DATA_WIDTH-1:0] sum [0:1];
  wire signed          [`DATA_WIDTH-1:0] relu_out [0:1];
  reg                  [`DATA_WIDTH-1:0] cdata_rd_sync;
  reg                  [`DATA_WIDTH-1:0] layer0_ker0_mem [0:4095];
  reg                  [`DATA_WIDTH-1:0] layer0_ker1_mem [0:4095];
  wire                 [`DATA_WIDTH-1:0] max_pool_ker0 [0:1023];
  wire                 [`DATA_WIDTH-1:0] max_pool_ker1 [0:1023];
  wire                            [12:0] read_layer0_idx;
  wire                             [0:1] conv_mem_sel;
  wire            [`LOCAL_IDX_WIDTH-1:0] double_local_idx;
  wire                            [10:0] max_pool_idx;
  wire                             [7:0] conv_out_idx;
  wire            [`LOCAL_IDX_WIDTH-1:0] out_row_offset;

  // Generate input address
  assign in_row_offset = row_idx * 66;
  assign addr0_sel = (local_idx < `IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
  assign addr1_sel = (local_idx >= `IN_BUFFER_SIZE && 
                      local_idx < 2*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
  assign addr2_sel = (local_idx >= 2*`IN_BUFFER_SIZE && 
                      local_idx < 3*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
  always @(posedge clk or posedge reset) begin
     if(reset) begin
       pseudo_addr <= {`LOCAL_IDX_WIDTH{1'b0}};
     end else if (flags[`F_GEN_IN_ADDR]) begin
        case({addr0_sel, addr1_sel, addr2_sel})
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
  assign read_in_idx = (local_idx >= `READ_MEM_DELAY) ? 
                       (local_idx - `READ_MEM_DELAY) : 0;
  assign m0_sel = (read_in_idx < `IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
  assign m1_sel = (read_in_idx >= `IN_BUFFER_SIZE && 
                   read_in_idx < 2*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
  assign m2_sel = (read_in_idx >= 2*`IN_BUFFER_SIZE && 
                   read_in_idx < 3*`IN_BUFFER_SIZE) ? 1'b1 : 1'b0;
  // Push FIFO into PE
  reg signed [7:0] feed_in_idx;
  integer          buf_idx;
  always @(posedge clk or posedge reset) begin
     if(reset) begin
        for(buf_idx = 0 ; buf_idx < `IN_BUFFER_SIZE ; buf_idx = buf_idx + 1) begin
            in_mem0[buf_idx] <= `EMPTY_DATA;
            in_mem1[buf_idx] <= `EMPTY_DATA;
            in_mem2[buf_idx] <= `EMPTY_DATA;
        end
     end else if ( flags[`F_READ_IN_ENB] ) begin      
         case({m0_sel, m1_sel, m2_sel})
           3'b100:
             in_mem0[read_in_idx] <= idata_sync;
           3'b010:
             in_mem1[read_in_idx - `IN_BUFFER_SIZE] <= idata_sync;
           3'b001:
             in_mem2[read_in_idx - 2*`IN_BUFFER_SIZE] <= idata_sync;
         endcase
     end else if (flags[`F_CONV_RELU_ENB] ) begin
         for(feed_in_idx=0 ; feed_in_idx < `IN_BUFFER_SIZE-1 ;
             feed_in_idx = feed_in_idx + 1) begin
            in_mem0[feed_in_idx] <= in_mem0[feed_in_idx+1];
            in_mem1[feed_in_idx] <= in_mem1[feed_in_idx+1];
            in_mem2[feed_in_idx] <= in_mem2[feed_in_idx+1];
         end
     end
  end

  // 1D convolution unit
  assign mul_enb = flags[`F_CONV_RELU_ENB];
  // Kernel 0
  PE_1D pe_0 (
              .clk(clk), .enb(mul_enb),
              .f0(w_mem0[0]), .f1(w_mem0[1]), .f2(w_mem0[2]),
              .in0(in_mem0[0]), .in1(in_mem0[1]), .in2(in_mem0[2]),
              .out_reg(conv_out_raw[0]));

  PE_1D pe_1 (
              .clk(clk), .enb(mul_enb),
              .f0(w_mem0[3]), .f1(w_mem0[4]), .f2(w_mem0[5]),
              .in0(in_mem1[0]), .in1(in_mem1[1]), .in2(in_mem1[2]),
              .out_reg(conv_out_raw[1]));

  PE_1D pe_2 (
              .clk(clk), .enb(mul_enb),
              .f0(w_mem0[6]), .f1(w_mem0[7]), .f2(w_mem0[8]),
              .in0(in_mem2[0]), .in1(in_mem2[1]), .in2(in_mem2[2]),
              .out_reg(conv_out_raw[2]));

  // Kernel 1
  PE_1D pe_3 (
              .clk(clk), .enb(mul_enb),
              .f0(w_mem1[0]), .f1(w_mem1[1]), .f2(w_mem1[2]),
              .in0(in_mem0[0]), .in1(in_mem0[1]), .in2(in_mem0[2]),
              .out_reg(conv_out_raw[3]));

  PE_1D pe_4 (
              .clk(clk), .enb(mul_enb),
              .f0(w_mem1[3]), .f1(w_mem1[4]), .f2(w_mem1[5]),
              .in0(in_mem1[0]), .in1(in_mem1[1]), .in2(in_mem1[2]),
              .out_reg(conv_out_raw[4]));

  PE_1D pe_5 (
              .clk(clk), .enb(mul_enb),
              .f0(w_mem1[6]), .f1(w_mem1[7]), .f2(w_mem1[8]),
              .in0(in_mem2[0]), .in1(in_mem2[1]), .in2(in_mem2[2]),
              .out_reg(conv_out_raw[5]));

  // Compute partial sum of 3 rows of kernel 0 and kernel 1
  assign p_sum_raw[0] = conv_out_raw[0] + conv_out_raw[1] + conv_out_raw[2]; // kernel 0
  assign p_sum_raw[1] = conv_out_raw[3] + conv_out_raw[4] + conv_out_raw[5]; // kernel 1
  // Compute rounding partial sum
  assign sum[0] = p_sum_raw[0][2*`DATA_WIDTH-5:`DATA_WIDTH-4] + p_sum_raw[0][`DATA_WIDTH-5] + b_0; // kernel 0
  assign sum[1] = p_sum_raw[1][2*`DATA_WIDTH-5:`DATA_WIDTH-4] + p_sum_raw[1][`DATA_WIDTH-5] + b_1; // kernel 1
  // Compute ReLU
  assign relu_out[0] = (sum[0][`DATA_WIDTH-1] == 1'b1) ? 0 : sum[0];
  assign relu_out[1] = (sum[1][`DATA_WIDTH-1] == 1'b1) ? 0 : sum[1];
  // Convolution output FIFO
  reg signed [7:0] out_idx;
  always @(posedge clk, posedge reset) begin
     if(reset) begin
        for(out_idx = 0 ; out_idx <=  `OUT_BUFFER_SIZE-1 ; out_idx = out_idx + 1) begin
           conv_out_fifo_ker0[out_idx] <= `EMPTY_DATA;
           conv_out_fifo_ker1[out_idx] <= `EMPTY_DATA;
        end
     end else if (flags[`F_CONV_RELU_ENB]) begin
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

  // Synchronize the async signal cdata_rd
  always @(posedge clk) begin
     cdata_rd_sync <= cdata_rd;
  end

  // Read from Layer 0
  assign read_layer0_idx = (local_idx >= `READ_MEM_DELAY) ?
                           (local_idx - `READ_MEM_DELAY) : 13'b0;
  assign conv_mem_sel = {(read_layer0_idx < 4096) ?
                         1'b1 : 1'b0, (read_layer0_idx >= 4096 && 
                                       read_layer0_idx < 2*4096) ? 
                                                    1'b1 : 1'b0};
  always @(posedge clk) begin
     if(flags[`F_READ_CONV_ENB]) begin
        case(conv_mem_sel)
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
  genvar 		  i, j;
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
  assign double_local_idx = {local_idx[`LOCAL_IDX_WIDTH-2:0], 1'b0};
  assign max_pool_idx = local_idx;
  assign conv_out_idx = local_idx;
  assign out_row_offset = row_idx * 64;
  always @(posedge clk, posedge reset) begin
     if(reset) begin
         cwr <= 1'b0;
         csel <= 3'b000;
         caddr_wr <= `EMPTY_ADDR;
         cdata_wr <= `EMPTY_DATA;
         caddr_rd <= `EMPTY_ADDR;
         crd <= 1'b0;
     end else if(flags[`F_WRITE_CONV_ENB]) begin
         caddr_rd <= `EMPTY_ADDR;
         crd <= 1'b0;
         cwr <= 1'b1;
         if(conv_out_idx < `OUT_BUFFER_SIZE) begin
           csel <= 3'b001;
           caddr_wr <= out_row_offset + conv_out_idx;
           cdata_wr <= conv_out_fifo_ker0[conv_out_idx];
         end else if(conv_out_idx >= `OUT_BUFFER_SIZE &&
                     conv_out_idx < 2*`OUT_BUFFER_SIZE) begin
           csel <= 3'b010;
           caddr_wr <= out_row_offset + (conv_out_idx - `OUT_BUFFER_SIZE);
           cdata_wr <= conv_out_fifo_ker1[conv_out_idx - `OUT_BUFFER_SIZE];
         end
     end else if(flags[`F_GEN_CONV_ADDR]) begin
       caddr_wr <= `EMPTY_ADDR;
       cdata_wr <= `EMPTY_DATA;
       cwr <= 1'b0;
       crd <= 1'b1;
       if(local_idx < 4096) begin
         csel <= 3'b001;
         caddr_rd <= local_idx;
       end else if(local_idx >= 4096 && local_idx < 2*4096) begin
         csel <= 3'b010;
         caddr_rd <= (local_idx - 4096);
       end
     end else if(flags[`F_WRITE_POOL_ENB]) begin
       caddr_rd <= `EMPTY_ADDR;
       crd <= 1'b0;
       cwr <= 1'b1;
       if(local_idx < 1024)begin
         csel <= 3'b011;
         caddr_wr <= local_idx;
         cdata_wr <= max_pool_ker0[max_pool_idx];
       end else if(local_idx >= 1024 && local_idx < 2*1024) begin
         csel <= 3'b100;
         caddr_wr <= (local_idx - 1024);
         cdata_wr <= max_pool_ker1[max_pool_idx - 1024];
       end
     end else if(flags[`F_WRITE_FLAT_ENB]) begin
       caddr_rd <= `EMPTY_ADDR;
       crd <= 1'b0;
       cwr <= 1'b1;
       if(local_idx < 1024) begin
         csel <= 3'b101; // Write to layer 2 (flattening layer)
         caddr_wr <= double_local_idx;
         cdata_wr <= max_pool_ker0[max_pool_idx];
       end else if(local_idx >= 1024 && local_idx < 2*1024) begin
         csel <= 3'b101; // Write to layer 2 (flattening layer)
         caddr_wr <= (double_local_idx - 2*1024 + 1);
         cdata_wr <= max_pool_ker1[max_pool_idx - 1024];
       end
     end else begin
       cwr <= 1'b0;
       csel <= 3'b000;
       caddr_wr <= `EMPTY_ADDR;
       cdata_wr <= `EMPTY_DATA;
       caddr_rd <= `EMPTY_ADDR;
       crd <= 1'b0;
     end
  end

endmodule
