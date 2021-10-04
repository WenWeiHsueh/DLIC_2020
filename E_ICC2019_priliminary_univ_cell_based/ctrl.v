`include "def.v"

module ctrl (
    input clk,
    input reset,
    output dp_cnt_rst, 
)
reg [`STATE_W-1:0] curr_state, next_state;

//State Register (S)
always @(posedge clk) begin
    if (reset) begin
        curr_state <= 1'b1;
    end else begin
        curr_state <= next_state; 
    end
end

//Next State Logic (C)
always @(*) begin
    next_state = `S_ZVEC;

    case (1'b1)
        curr_state[`S_PRE]: begin
            if (start_conv == 1'b1) begin
                next_state[`S_SET] = 1'b1;
            end else begin
                next_state[`S_PRE] = 1'b1;
            end
        end
        curr_state[`S_SET]: begin
            if (set_done) begin
                next_state[`S_READ] = 1'b1;
            end else begin
                next_state[`S_SET] = 1'b1;
            end
        end
        curr_state[`S_READ]: begin
            if (read_done) begin
                next_state[`S_MULT] = 1'b1;
            end else begin
                next_state[`S_READ] = 1'b1;
            end    
        end
        curr_state[`S_MULT]: begin
            if (mult_done) begin
                next_state[`S_ROUND] = 1'b1;
            end else begin
                next_state[`S_MULT] = 1'b1;
            end
        end
        curr_state[`S_ROUND]: begin
            if (round_done) begin
                next_state[`S_ADD] = 1'b1;
            end else begin
                next_state[`S_ROUND] = 1'b1;
            end
        end
        curr_state[`s_ADD]: begin
            if (add_done) begin
                next_state[`S_WRITE] = 1'b1;
            end else begin
                next_state[`S_ADD] = 1'b1;
            end
        end
        curr_state[`S_WRITE]: begin
            if (write_all_done) begin
                next_state[`S_END] = 1'b1;
            end else if (write_nyet_done) begin
                next_state[`S_SET] = 1'b1;
            end else begin
                next_state[`S_WRITE] = 1'b1;
            end
        end
        default: 
    endcase
end

//Output Logic (C)
always @(*) begin
    cmd_flags = {`CMD_FLAG_W{1'b0}}; 
    dp_cnt_rst = 1'b0;

    case (1'b1)
        curr_state[`S_SET]: begin
            cmd_flags[`CMD_SET] = 1'b1;
        end
        curr_state[`S_READ]: begin
            cmd_flags[`CMD_READ] = 1'b1;
            if(read_done) begin
                dp_cnt_rst = 1'b1;
            end 
        end
        curr_state[`S_MULT]: begin
            cmd_flags[`CMD_MULT] = 1'b1;
            if(mult_done) begin
                dp_cnt_rst = 1'b1;
            end 
        end
        curr_state[`S_ROUND]: begin
            cmd_flags[`CMD_ROUND] = 1'b1;
            if(round_done) begin
                dp_cnt_rst = 1'b1;
            end 
        end
        curr_state[`S_ADD]: begin
            cmd_flags[`CMD_ADD] = 1'b1;
            if(add_done) begin
                dp_cnt_rst = 1'b1;
            end 
        end
        curr_state[`S_WRITE]: begin
            cmd_flags[`CMD_WRITE] = 1'b1;
        end
        default: 
    endcase
end