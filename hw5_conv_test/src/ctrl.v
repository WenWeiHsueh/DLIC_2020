module ctrl (
    input clk,
    input reset,
    input start,
);
    reg [`STATE_W-1:0] curr_state, next_state;
    
    // State Register (S)
    always @(posedge clk) begin
        if (reset) begin
            curr_state <= 0;    
        end else begin
            curr_state <= next_state;
        end
    end // State Register (S)
    
    // Next State Logic (C)
    always @(*) begin
        next_state = `S_ZVEC;

        case (curr_state)

            //WAIT state
            curr_state[`S_WAIT]: begin
                if(wait_done)
            end
    end
endmodule