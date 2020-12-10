`timescale 1ns / 10ps
module booth(out, in1, in2);

parameter DATA_WIDTH = 6;

input   [DATA_WIDTH-1:0]   in1; //multiplicand
input   [DATA_WIDTH-1:0]   in2; //multiplier
output  [2*DATA_WIDTH-1:0] out; //product


/*write your code here*/
reg     [2*DATA_WIDTH:0] p;
integer i;

assign out = p[2*DATA_WIDTH:1];

always@ (in1 or in2) begin

    p = {{DATA_WIDTH{1'b0}}, in2, 1'b0};

    for(i = 0; i < DATA_WIDTH; i = i + 1) begin

        case(p[1:0])
            2'b01:
                p[2*DATA_WIDTH:DATA_WIDTH+1] = p[2*DATA_WIDTH:DATA_WIDTH+1] + in1;
            2'b10:
                p[2*DATA_WIDTH:DATA_WIDTH+1] = p[2*DATA_WIDTH:DATA_WIDTH+1] - in1;
            default:
                p[2*DATA_WIDTH:DATA_WIDTH+1] = p[2*DATA_WIDTH:DATA_WIDTH+1] + {DATA_WIDTH{1'b0}};
        endcase

        p = {p[2*DATA_WIDTH], p} >> 1;
    end
end

endmodule
