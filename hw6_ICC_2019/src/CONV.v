`include "def.v"

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

// Flags
wire [`FLAG_WIDTH-1:0] flags;

// Synchronize reset signal
reg sync_reset;
always @(posedge clk) begin 
    if(reset)
        sync_reset <= 1'b1;
    else
        sync_reset <= 1'b0;
end

// Local index counter
reg [`LOCAL_IDX_WIDTH-1:0] local_idx;
wire local_idx_rst;
always @(posedge clk) begin
    if(sync_reset || local_idx_rst)
        local_idx <= {`LOCAL_IDX_WIDTH{1'b0}};
    else
        local_idx <= local_idx + 1'b1;
end


// Catch the negedge of flags[`F_WRITE_CONV_ENB]
reg sample_conv_enb;
always @(posedge clk) begin
    if(flags[`F_WRITE_CONV_ENB])
        sample_conv_enb <= 1'b1;
    else
        sample_conv_enb <= 1'b0;
end

reg latch_conv_enb;
always @(clk) begin
    if(!clk) begin
        latch_conv_enb <= flags[`F_WRITE_CONV_ENB];
    end
end

wire neg = !latch_conv_enb & sample_conv_enb;

// Row index counter
reg [7:0] row_idx;
always @(posedge clk, posedge sync_reset) begin
    if(sync_reset)
        row_idx <= 8'h00;
    else
        row_idx <= neg ? row_idx + 1'b1 : row_idx;
end

// Controller
convCtrl conv_controller (
    .clk(clk), 
    .reset(sync_reset), 
    .busy(busy),
    .ready(ready), 
    .local_idx(local_idx),
    .local_idx_rst(local_idx_rst),
    .row_idx(row_idx), 
    .flags(flags)
);

// Convolution Data Path
convDataPath conv_data_path (
    .clk(clk),
    .iaddr(iaddr), 
    .idata(idata),
    .cwr(cwr), 
    .caddr_wr(caddr_wr), 
    .cdata_wr(cdata_wr),
    .crd(crd), 
    .caddr_rd(caddr_rd), 
    .cdata_rd(cdata_rd),
    .csel(csel),
    .flags(flags),
    .local_idx(local_idx), 
    .row_idx(row_idx)
);

endmodule
