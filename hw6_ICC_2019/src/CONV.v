`include "flag_def.v"

module  CONV(
            input         wire         clk,
            input         wire         reset,
            output        wire         busy,
            input         wire         ready,

            output        wire         [11:0] iaddr,
            input         wire         [19:0] idata,
            output        wire         cwr,
            output        wire         [11:0] caddr_wr,
            output        wire         [19:0] cdata_wr,

            output        wire         crd,
            output        wire         [11:0] caddr_rd,
            input         wire         [19:0] cdata_rd,

            output        wire         [2:0] csel
        );

localparam DATA_WIDTH = 20;
localparam LOCAL_IDX_WIDTH = 16;

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
reg [7:0] row_idx = 8'h00;
always @(negedge flags[`F_WRITE_CONV_ENB], posedge reset) begin
    if(reset)
        row_idx <= 8'h00;
    else
        row_idx <= row_idx + 1;
end

// Controller
convCtrl #(  
            .LOCAL_IDX_WIDTH (LOCAL_IDX_WIDTH)
         ) conv_controller (
             .clk(clk), .reset(reset), .busy(busy),
             .ready(ready), .local_idx(local_idx),
             .local_idx_rst(local_idx_rst),
             .row_idx(row_idx), .flags(flags)
         );

// Convolution Data Path
convDataPath #(
                .LOCAL_IDX_WIDTH (LOCAL_IDX_WIDTH),
                .DATA_WIDTH (DATA_WIDTH)
             ) conv_data_path (
                 .clk(clk), .iaddr(iaddr), .idata(idata),
                 .cwr(cwr), .caddr_wr(caddr_wr), .cdata_wr(cdata_wr),
                 .crd(crd), .caddr_rd(caddr_rd), .cdata_rd(cdata_rd),
                 .csel(csel),
                 .flags(flags),
                 .local_idx(local_idx), .row_idx(row_idx)
             );

endmodule
