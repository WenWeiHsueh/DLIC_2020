module  zeropadding(
  input                                 clk,
  input                          [11:0] pseudo_addr,
  output reg                     [11:0] iaddr,
  input                          [19:0] idata,
  output reg                     [19:0] data
);

reg [0:0] z_flag;

always @(*) begin
    z_flag = 1'b0;
    if (pseudo_addr <= 66) begin
        z_flag = 1'b1;
    end else if (pseudo_addr >= 66 * 65 - 1) begin//the bottom
        z_flag = 1'b1;
    end else if ((pseudo_addr - 66) % 66 == 0) begin
        z_flag = 1'b1;
    end else if ((pseudo_addr - 66) % 66 == 65) begin
        z_flag = 1'b1;
    end
end

always @(posedge clk) begin//registered output
    if (z_flag == 0) begin
        iaddr <= pseudo_addr - 66 - 1 - (((pseudo_addr / 66) - 1) * 2);
    end
end

always @(*) begin
    data = 0;
    if (z_flag) begin
        data = 0;
    end else begin
        data = idata;
    end
end

endmodule