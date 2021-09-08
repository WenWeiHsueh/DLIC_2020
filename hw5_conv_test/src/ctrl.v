`include "def.v"

module ctrl (
    input clk,
    input reset,
    input start,
    input already_bias, 
    input already_weight
);
    reg [`STATE_W-1:0] curr_state, next_state;
    parameter PRE = 3'b000, SET = 3'b001, READ = 3'b010, MULT = 3'b011, ROUND = 3'b100, ADD = 3'b101, WRITE = 3'b110;
    
    // State Register (S)
    always @(posedge clk) begin
        if (reset) begin
            curr_state <= 0;    
        end else begin
            curr_state <= next_state;
        end
    end // State Register (S)
    
    wire read_w_b_done = already_weight & already_bias;
    
    // Next State Logic (C)
    always @(*) begin
        if (reset) begin
            next_state <= PRE;
        end else begin
            case (curr_state)
                PRE: begin
                    if (start) begin
                        if (read_w_b_done) begin
                            next_state <= SET;
                        end else begin
                            next_state <= next_state;
                        end 
                    end else begin
                        next_state <= next_state;
                    end
                end

                SET: begin
                    if (read_w_b_done) begin
                        next_state <= READ;
                    end else begin
                        next_state <= next_state;
                    end
                end

                READ: begin
                    if (my_addr % 28 != 26) begin
                        if (in_count < 8) begin
                            next_state <= SET;
                        end else begin
                            next_state <= MULT;
                        end 
                    end else begin
                        next_state <= SET;1                    
                    end
                end

                MULT: begin
                    next_state <= ROUND;
                end

                ROUND: begin
                    next_state <= ADD;
                end

                ADD: begin
                    next_state <= WRITE;
                end

                WRITE: begin
                    next_state <= SET;
                end

                default: begin
                    next_state <= SET;
                end
            endcase 
        end
    end // Next State Logic (C)

    //Output Logic (C)
    always @(*) begin
        case (curr_state)
            PRE: begin
                if (start) begin
                    if (read_w_b_done) begin
                        start_conv <= 1'b1;
                    end else begin
                        start_conv <= 1'b0;
                    end 
                end else begin
                    next_state <= next_state;
                end
            end

            SET: begin
                if (read_w_b_done) begin
                    next_state <= READ;
                end else begin
                    next_state <= next_state;
                end
            end

            READ: begin
                if (my_addr % 28 != 26) begin
                    if (in_count < 8) begin
                        next_state <= SET;
                    end else begin
                        next_state <= MULT;
                    end 
                end else begin
                    next_state <= SET;1                    
                end
            end

            MULT: begin
                next_state <= ROUND;
            end

            
            ROUND: begin
                next_state <= ADD;
            end

            ADD: begin
                next_state <= WRITE;
            end

            WRITE: begin
                next_state <= SET;
            end

            default: begin
                next_state <= SET;
            end
        endcase
    end

endmodule