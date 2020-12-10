module booth(out, in1, in2);

localparam DATA_WIDTH = 6;

input wire 	[DATA_WIDTH-1:0] in1; //multiplicand
input wire 	[DATA_WIDTH-1:0] in2; //multiplier
output reg   [2*DATA_WIDTH-1:0] out; //product

reg [DATA_WIDTH-1:0] cnt;
reg [2*DATA_WIDTH-1:0] prod;

reg [1:0] CurrentState;
reg [1:0] NextState;

parameter [1:0] ReadyState  = 2'b00,
          ProcState   = 2'b01,
          OutputState = 2'b10;

reg clk=0;
reg rst=1;
always begin
    clk = ~clk;
    #1;
end

always @(in1 , in2) begin
    rst = 1;
    #2;
    rst = 0;
end

// state register (S)
always @(posedge clk, negedge clk) begin
    if(rst) begin
        CurrentState <= ReadyState;
        cnt <= 0; //reset counter
        prod <= 0; // reset result variable
    end
    else
        CurrentState <= NextState;
end

//next state logic  (C)
always @(CurrentState, cnt) begin
    case (CurrentState)
        ReadyState:
            NextState = ProcState;
        ProcState: begin
            cnt = cnt + 1;
            if( cnt == DATA_WIDTH )
                NextState = OutputState;
            else
                NextState = ReadyState;
        end
        OutputState:
            NextState = OutputState;
        default:
            NextState = ReadyState;
    endcase
end

reg [1:0] TwinBits; // keep track of two bits from in2
reg [2*DATA_WIDTH-1:0] Tmp; // temporary variables
reg [2*DATA_WIDTH-1:0] ExtBits; // variable for sign-extension
wire [DATA_WIDTH:0] in2_ext = {in2, 1'b0}; // append 0 to the LSB

// output logic (C)
always @(CurrentState, in1, TwinBits) begin
    case (CurrentState)
        ReadyState:
            ;
        ProcState: begin
            // Get the consequtive bits from in2
            TwinBits = {in2_ext[cnt], in2_ext[cnt-1]};

            // Do sign extension
            Tmp = in1 << (cnt-1);
            if( in1[DATA_WIDTH-1] == 1 ) begin // in1 < 0
                ExtBits = -1 << (DATA_WIDTH + cnt - 1);
                Tmp = Tmp | ExtBits;
            end

            // +/- the shifted bits
            case(TwinBits)
                2'b10:
                    prod = prod - Tmp;
                2'b01:
                    prod = prod + Tmp;
                default:
                    ;
            endcase
        end
        OutputState:
            out = prod;
        default:
            ;
    endcase
end
endmodule
