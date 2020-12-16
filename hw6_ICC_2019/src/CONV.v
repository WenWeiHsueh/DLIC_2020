module  CONV(
            input         wire         clk,
            input         wire         reset,
            output        wire         busy,
            input         wire         ready,

            output        wire         [11:0]iaddr,
            input         wire         [19:0]idata,

            output        wire         cwr,
            output        wire         [11:0] caddr_wr,
            output        wire         [19:0] cdata_wr,

            output        wire         crd,
            output        wire         [11:0] caddr_rd,
            input         wire         [19:0] cdata_rd,

            output        wire         [2:0] csel
        );

localparam LOCAL_IDX_WIDTH = 16;
localparam DATA_WIDTH = 20;
localparam IN_BUFFER_SIZE = 66;
localparam OUT_BUFFER_SIZE = IN_BUFFER_SIZE - 2;
localparam F_GEN_IN_ADDR = 0, F_READ_IN_ENB = 1,
           F_CONV_RELU_ENB = 2, F_WRITE_CONV_ENB = 3,
           F_GEN_CONV_ADDR = 4, F_READ_CONV_ENB = 5,
           F_WRITE_POOL_ENB = 6, F_WRITE_FLAT_ENB = 7;
// Flags
wire [11:0] flags;

// Local index counter
reg [LOCAL_IDX_WIDTH-1:0] local_idx;
wire local_idx_rst;
always @(posedge clk) begin
    if(reset || local_idx_rst)
        local_idx <= {LOCAL_IDX_WIDTH{1'b0}};
    else
        local_idx <= local_idx + 1;
end

// Row index counter
reg [7:0] row_idx;
wire row_idx_rst;
wire row_idx_zero_sig = (reset || row_idx_rst);
always @(negedge flags[F_WRITE_CONV_ENB], posedge row_idx_zero_sig) begin
    if(row_idx_zero_sig)
        row_idx <= 8'h00;
    else
        row_idx <= row_idx + 1;
end

// Controller
convCtrl #(
             .LOCAL_IDX_WIDTH (LOCAL_IDX_WIDTH),
             .IN_BUFFER_SIZE (IN_BUFFER_SIZE),
             .OUT_BUFFER_SIZE (OUT_BUFFER_SIZE),
             .F_GEN_IN_ADDR (F_GEN_IN_ADDR),
             .F_READ_IN_ENB (F_READ_IN_ENB),
             .F_CONV_RELU_ENB (F_CONV_RELU_ENB),
             .F_WRITE_CONV_ENB (F_WRITE_CONV_ENB),
             .F_GEN_CONV_ADDR (F_GEN_CONV_ADDR),
             .F_READ_CONV_ENB (F_READ_CONV_ENB),
             .F_WRITE_POOL_ENB (F_WRITE_POOL_ENB),
             .F_WRITE_FLAT_ENB (F_WRITE_FLAT_ENB)
         ) conv_controller(
             .clk(clk), .reset(reset), .busy(busy),
             .ready(ready), .local_idx(local_idx),
             .local_idx_rst(local_idx_rst),
             .row_idx(row_idx), .row_idx_rst(row_idx_rst),
             .flags(flags)
         );

// Convolution Data Path
convDataPath #(
                 .LOCAL_IDX_WIDTH (LOCAL_IDX_WIDTH),
                 .DATA_WIDTH (DATA_WIDTH),
                 .IN_BUFFER_SIZE(IN_BUFFER_SIZE),
                 .OUT_BUFFER_SIZE (OUT_BUFFER_SIZE),
                 .F_GEN_IN_ADDR (F_GEN_IN_ADDR),
                 .F_READ_IN_ENB (F_READ_IN_ENB),
                 .F_CONV_RELU_ENB (F_CONV_RELU_ENB),
                 .F_WRITE_CONV_ENB (F_WRITE_CONV_ENB),
                 .F_GEN_CONV_ADDR (F_GEN_CONV_ADDR),
                 .F_READ_CONV_ENB (F_READ_CONV_ENB),
                 .F_WRITE_POOL_ENB (F_WRITE_POOL_ENB),
                 .F_WRITE_FLAT_ENB (F_WRITE_FLAT_ENB)
             ) conv_data_path(
                 .clk(clk), .iaddr(iaddr), .idata(idata),
                 .cwr(cwr), .caddr_wr(caddr_wr), .cdata_wr(cdata_wr),
                 .crd(crd), .caddr_rd(caddr_rd), .cdata_rd(cdata_rd),
                 .csel(csel),
                 .flags(flags),
                 .local_idx(local_idx), .row_idx(row_idx)
             );

endmodule
