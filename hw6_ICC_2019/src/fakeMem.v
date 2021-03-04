// This module translate the zero-padded 66x66 input memory index
// to the real 64x64 input memory index. By doing so, we don't need
// to "actually" do zero-padding
module fakeMem (
           input   wire    clk,
           input   wire    [`LOCAL_IDX_WIDTH-1:0] pseudo_addr,
           output  reg     [11:0] iaddr,
           output  reg     zero_flag
       );

// assume `LOCAL_IDX_WIDTH = 16
wire [2*`LOCAL_IDX_WIDTH-1:0] tmp = pseudo_addr * 16'h03E1;
wire [`LOCAL_IDX_WIDTH-1:0] quotient = tmp >> 16;
wire [7:0] mod66 = (pseudo_addr - (quotient * 66));

//wire [7:0] mod66 = pseudo_addr % 66;
//wire [`LOCAL_IDX_WIDTH-1:0] quotient = (pseudo_addr - mod66) / 66;

wire mod_cond = (mod66 == 0) || (mod66 == 65);
wire zero_cond = ((pseudo_addr >= 0) && (pseudo_addr <= 65)) || ((pseudo_addr >= 4290) && (pseudo_addr <= 4355)) || mod_cond;


always @(*) begin
    if(zero_cond) begin
        zero_flag = 1;
        iaddr = 12'hzzz; // sending nothing to address bus
    end
    else begin
        zero_flag = 0;
        iaddr = pseudo_addr - 67 - 2 * (quotient-1);
    end
end

endmodule
