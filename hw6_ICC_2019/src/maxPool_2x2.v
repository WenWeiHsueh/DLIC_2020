module maxPool_2x2 #(
           parameter DATA_WIDTH = 20
       )(
           input   wire    [DATA_WIDTH-1:0] in0,
           input   wire    [DATA_WIDTH-1:0] in1,
           input   wire    [DATA_WIDTH-1:0] in2,
           input   wire    [DATA_WIDTH-1:0] in3,
           output  wire    [DATA_WIDTH-1:0] max
       );

wire [DATA_WIDTH-1:0] cmp_0 = (in0 > in1) ? in0 : in1;
wire [DATA_WIDTH-1:0] cmp_1 = (in2 > in3) ? in2 : in3;
assign max = (cmp_0 > cmp_1) ? cmp_0 : cmp_1;

endmodule
