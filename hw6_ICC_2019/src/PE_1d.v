module PE_1d #(
           parameter DATA_WIDTH = 20
       )(
           input   wire    clk,
           input   wire    enb,
           input   wire    signed [DATA_WIDTH-1:0] f0, f1, f2, // filter
           input   wire    signed [DATA_WIDTH-1:0] in0, in1, in2, // input
           output  reg     signed [2*DATA_WIDTH-1:0] out_reg // output
       );

// Input FIFO
reg signed [DATA_WIDTH-1:0] in_fifo [0:2];

wire zero_test [0:2];
assign zero_test[0] = ((f0 == 0) || (in_fifo[0] == 0));
assign zero_test[1] = ((f1 == 0) || (in_fifo[1] == 0));
assign zero_test[2] = ((f2 == 0) || (in_fifo[2] == 0));

wire signed [2*DATA_WIDTH-1:0] mul_raw [0:2];
assign mul_raw[0] = zero_test[0] ? 0 : (in_fifo[0] * f0);
assign mul_raw[1] = zero_test[1] ? 0 : (in_fifo[1] * f1);
assign mul_raw[2] = zero_test[2] ? 0 : (in_fifo[2] * f2);

wire sum_zero = zero_test[0] && zero_test[1] && zero_test[2];

wire signed [2*DATA_WIDTH-1:0] mul_raw_sum = sum_zero ? 0 : (mul_raw[0] + mul_raw[1] + mul_raw[2]);

always @(negedge clk) begin
    if(enb == 1'b1) begin
        in_fifo[0] <= in0;
        in_fifo[1] <= in1;
        in_fifo[2] <= in2;
        out_reg <= mul_raw_sum;
    end
end

endmodule
