`timescale 1ns/10ps
module CS(Y,
          X,
          reset,
          clk);

input clk, reset;
input wire [7:0] X;
output reg [9:0] Y;

// Counter that counts two cycles of reset signal
reg [2:0] rst_cnt;
// Internal state counter
reg [3:0] cnt;
// A buffer for SISO shifter
reg [7:0] buffer [8:0];

// FSM state register
reg [1:0] curr_state, next_state;
// FSM state declaration
parameter [1:0]
          READY_STATE = 2'b00,
          READ_STATE = 2'b01,
          OUTPUT_STATE = 2'b10;

// State register (S)
always @(posedge clk, posedge reset) begin
    if (reset) begin
        curr_state <= READY_STATE;
    end
    else begin
        curr_state <= next_state;
    end
end

//  Counter increment
always @(posedge clk) begin
    if (reset) begin
        rst_cnt <= rst_cnt + 1;
    end
    else begin
        rst_cnt <= 0;
        if (cnt == 4'h9)
            cnt <= 4'h9;
        else
            cnt <= cnt + 1;
    end
end

// Next state logic (Comb)
always @(curr_state or rst_cnt or cnt) begin
    case(curr_state)
        READY_STATE: begin
            if (rst_cnt != 2)
                next_state = READY_STATE;
            else // Jump to next state if 2 reset cycles have been counted
                next_state = READ_STATE;
        end
        READ_STATE: begin
            if (cnt != 9)
                next_state = READ_STATE;
            else begin // Jump to next state if 9 bits have been read
                next_state = OUTPUT_STATE;
            end
        end
        OUTPUT_STATE:
            next_state = OUTPUT_STATE;
        default:
            next_state = READY_STATE;
    endcase
end

// Buffer index
reg [3:0] itrIdx, approxIdx;
// xAppr is the largest element in buffer that's smaller than xAvg
// diff is a temporary variable that keeps track of the difference between buffer[i] and xAvg
reg [8:0] xAppr, diff;
// bufferSum is the sum of all elements in buffer
wire [40:0] bufferSum = buffer[0] + buffer[1] + buffer[2] + buffer[3] + buffer[4] + buffer[5] + buffer[6] + buffer[7] + buffer[8];
// bufferSum / 9
wire [8:0] xAvg = (bufferSum * 32'h1C71C71D) >> 32;
// OutputY = (bufferSum + xAppr * 9) / 8
wire [9:0] OutputY = (xAppr * 9 + bufferSum) >> 3;

// Output logic (Comb) for OutputY
always @(curr_state or buffer[8] or xAvg or diff) begin

    diff  = 9'h0FF;
    xAppr     = 9'h000;
    approxIdx = 0;
    case(curr_state)
        READY_STATE:
            ;
        READ_STATE:
            ;
        OUTPUT_STATE: begin
            // Find xAppr in buffer
            for(itrIdx = 0 ; itrIdx <= 8 ; itrIdx = itrIdx + 1)
                if ((xAvg - buffer[itrIdx] < diff) && (xAvg - buffer[itrIdx]) > 0) begin
                    approxIdx = itrIdx;
                    diff  = xAvg - buffer[itrIdx];
                end
                else if (xAvg - buffer[itrIdx] == 0) begin
                    approxIdx = itrIdx;
                    diff  = 0;
                end
            xAppr = buffer[approxIdx];
        end
        default:
            ;
    endcase
end

// Write to Y
wire nclk = ~clk;
always @(posedge nclk) begin
    Y <= OutputY;
end

// SISO shifter
reg [3:0] idx, i;
always @(posedge clk) begin
    if (reset == 0) begin
        // buffer shift & read input
        for(idx = 0 ; idx != 4'b1000 ; idx = idx + 1) begin
            buffer[idx] <= buffer[idx+1];
        end
        buffer[8] <= X;
    end
    else begin
        for(i = 0 ; i != 4'b1000 ; i = i + 1)
            buffer[i] <= 8'h00;
    end
end

endmodule
