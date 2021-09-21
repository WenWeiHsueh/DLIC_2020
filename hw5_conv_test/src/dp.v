module dp(
  input                               clk,
  input                               reset,
  input                               cnt_rst,
  output reg        [`ADDR_WIDTH-1:0] M0_addr,
  input             [`DATA_WIDTH-1:0] M0_R_data,
  output reg        [`DATA_WIDTH-1:0] M0_W_data,
  output reg                          M0_R_req,
  output reg                    [3:0] M0_W_req,
  output reg        [`ADDR_WIDTH-1:0] M1_addr,
  input             [`DATA_WIDTH-1:0] M1_R_data,
  output reg        [`DATA_WIDTH-1:0] M1_W_data,
  output reg                          M1_R_req,
  output reg                    [3:0] M1_W_req,
  output reg                          finish,
  output reg            [`STATE_DONE] done_state
);
    input         rst;
    input         clk;
    input  [31:0] M0_R_data;
    input  [31:0] M1_R_data;     //use or not
    input         start;

    output        M0_R_req;
    output [3:0]  M0_W_req;     //use or not
    output [31:0] M0_addr;
    output [31:0] M0_W_data;    //use or not
    output        M1_R_req; 
    output [3:0]  M1_W_req;
    output [31:0] M1_addr;
    output [31:0] M1_W_data;
    output        finish;
	
    reg [31:0] M0_addr;
    reg        M0_R_req;
    reg [3:0]  M0_W_req;
    reg [31:0] M0_W_data;
    reg [31:0] M1_W_data;
    reg        finish;
    reg        M1_R_req;
    reg [3:0]  M1_W_req;
    reg [31:0] M1_addr;

    reg [31:0] Reg_input     [8:0];
    reg [31:0] Reg_weight    [8:0];
    reg [31:0] Reg_bias;
    reg [31:0] Reg_result    [8:0];
    reg [63:0] Reg_mult      [8:0];
    reg [63:0] Reg_count_fin;
    reg [2:0]  state;
    reg [0:0]  start_conv;
    reg [0:0]  start_read;
    reg [0:0]  already_weight;
    reg [0:0]  already_bias;
    reg [0:0]  read_weight;
    reg [0:0]  read_bias;
    reg [4:0]  in_count; // the index of input data
    reg [7:0]  count; // to count the current # of data
    reg [31:0] my_addr;
    reg [0:0]  check; // to check if the input data follow the rules of convolution
    reg [4:0]  i;


    parameter PRE = 3'b000, SET = 3'b001, READ = 3'b010, MULT = 3'b011, 
            ROUND = 3'b100, ADD = 3'b101, WRITE = 3'b110;
    
    wire read_w_b_done;

    assign read_w_b_done = already_weight & already_bias;

    // // done_state
    // always @(posedge clk) begin
    //     if (rst == 0) begin
    //         done_state <= 6'b0;
    //     end else begin
    //         done_state <= 6'b0;
    //         case (curr_state)
    //             PRE: begin
    //                 if (read_w_b_done) begin
    //                     done_state[`PRE] <= 1;
    //                 end else begin
    //                     done_state <= done_state;
    //                 end
    //             end 
                
    //             SET: begin
    //                 if () begin
    //                 end
    //             end
    //     end
    // end

    // M0_W_data
    always @(posedge clk) begin
    	if (rst == 0) begin
	        M0_W_data <= 32'b0;
        end else begin
	        M0_W_data <= M0_W_data;
	    end
    end

    // read_weight
    always @(posedge clk) begin
        if (rst == 0) begin
            read_weight <= 1'b1;
        end else begin
            if (already_weight == 1'b1) begin
                read_weight <= 1'b0;
            end else begin
                read_weight <= read_weight; 
            end
        end
    end
    
    // read_bias
    always @(posedge clk) begin
        if (rst == 0) begin
            read_bias <= 1'b1;
        end else begin
            if (already_bias == 1'b1) begin
                read_bias <= 1'b0;
            end else begin
                read_bias <= read_bias; 
            end
        end
    end

    // read Weights
    always @(posedge clk) begin
        if (rst == 0) begin
            for (i = 0; i < 9; i = i + 1) begin
                Reg_weight[i] <= 32'b0;
            end
        end else begin
            if (M0_R_req == 1 && start_read == 1'b1 && already_weight == 1'b0) begin
                Reg_weight[(M0_addr - 4) / 4 - 784] <= M0_R_data;
            end else begin
                for (i = 0; i < 9; i = i + 1) begin
                    Reg_weight[i] <= Reg_weight[i];
                end
            end
        end
    end

    // read Bias
    always @(posedge clk) begin
        if (rst == 0) begin
            Reg_bias <= 32'b0;
        end else begin
            if (M0_R_req == 1 && start_read == 1'b1 && already_bias == 1'b0 && already_weight == 1'b1) begin
                Reg_bias <= M0_R_data;
            end else begin
                Reg_bias <= Reg_bias;
            end
        end
    end

    // already_weight
    always @(posedge clk) begin
        if (rst == 0) begin
            already_weight <= 1'b0;
        end else begin
            if (M0_addr > 792 << 2) begin
                already_weight <= 1'b1;
            end else begin
                already_weight <= already_weight;
            end
        end
    end

    // already_bias
    always @(posedge clk) begin
        if (rst == 0) begin
            already_bias <= 1'b0;
        end else begin
            if (Reg_bias != 32'b0) begin
                already_bias <= 1'b1;
            end else begin
                already_bias <= already_bias; 
            end
        end
    end

    // M0_R_req
    always @(posedge clk) begin
        if (rst == 0) begin
            M0_R_req <= 0;
        end else begin
            if (start_read == 1) begin
                M0_R_req <= 1;
            end else begin
                M0_R_req <= M0_R_req;
            end
        end
    end

    // start_conv
    always @(posedge clk) begin
        if (rst == 0) begin
            start_conv <= 1'b0;
        end else begin
            if(already_weight == 1'b1 && already_bias == 1'b1) begin
                start_conv <= 1'b1;
            end else begin
                start_conv <= start_conv;
            end
        end
    end

    // start_read
    always @(posedge clk) begin
        if(start == 1'b1) begin
            start_read <= 1'b1;
        end else begin
            start_read <= start_read;
        end
    end

    // finish
    always @(posedge clk) begin
        if (rst == 0) begin
            finish <= 0;
        end else begin
            if (my_addr > 28 * 26 - 1) begin
                finish <= 1;
            end else begin
                finish <= finish;
            end
        end
    end

    // count M0_addr, my_addr
    always @(posedge clk) begin
        if (rst == 0) begin
            my_addr <= 32'b0;
            M0_addr <= 32'b0;
        end else begin // read weight
            if (start_read == 1'b1) begin
                if (read_weight == 1'b1) begin
                    if (already_weight == 1'b0) begin
                        if (M0_addr < 783 << 2) begin
                            M0_addr <= 783 << 2;
                            my_addr <= my_addr;
                        end else if (M0_addr > 792 << 2) begin
                            M0_addr <= M0_addr;
                            my_addr <= my_addr;
                        end else begin
                            M0_addr <= M0_addr + 4;
                            my_addr <= my_addr;
                        end
                    end else begin
                        M0_addr <= M0_addr;
                    end
                end else if (read_bias == 1'b1) begin
                    if (already_bias == 1'b0) begin
                        if (M0_addr < 793 << 2) begin
                            M0_addr <= 793 << 2;
                            my_addr <= my_addr;
                        end else if (M0_addr > 793 << 2) begin
                            M0_addr <= M0_addr;
                            my_addr <= my_addr;
                        end else begin
                            M0_addr <= M0_addr + 4;
                            my_addr <= my_addr;
                        end
                    end else begin
                        M0_addr <= M0_addr;
                        my_addr <= my_addr;
                    end
                end else begin
                    if (state == PRE) begin
                        my_addr <= 32'b0;
                        M0_addr <= 32'b0;
                    end else if (state == READ) begin
                        if (my_addr % 28 != 26) begin
                            if (in_count == 8) begin // to store the initial addr
                                my_addr <= my_addr + 1;
                                M0_addr <= (my_addr + 1 + count) << 2;
                            end else begin
                                my_addr <= my_addr;
                                M0_addr <= (my_addr + count) << 2;
                            end
                        end else begin
                            my_addr <= my_addr + 2;
                            M0_addr <= (my_addr + 2) << 2;
                        end
                    end else begin
                        my_addr <= my_addr;
                        M0_addr <= M0_addr;
                    end
                end 
            end else begin
                M0_addr <= M0_addr;
                my_addr <= my_addr;
            end
        end
    end

    // count
    always @(posedge clk) begin
        if (rst == 0) begin
            count <= 0;
        end else begin
            if (curr_state == SET) begin
                case (count)
                    0: begin
                        count <= 1;
                    end 
                    1: begin
                        count <= 2;
                    end
                    2: begin
                        count <= 28;
                    end
                    28: begin
                        count <= 29;
                    end
                    29: begin
                        count <= 30;
                    end
                    30: begin
                        count <= 56;
                    end
                    56: begin
                        count <= 57;
                    end
                    57: begin
                        count <= 58;
                    end
                    58: begin
                        count <= 0;
                    end
                    default: begin
                        count <= 9;
                    end
                endcase 
            end else begin
                count <= count;
            end
        end
    end

    // in_count
    always @(posedge clk) begin
        if (rst == 0) begin
            in_count <= 0;
        end else begin
            if (curr_state == READ) begin
                case (count)
                    0: begin
                        in_count <= 0;
                    end 
                    1: begin
                        in_count <= 1;
                    end
                    2: begin
                        in_count <= 2;
                    end
                    28: begin
                        in_count <= 3;
                    end
                    29: begin
                        in_count <= 4;
                    end
                    30: begin
                        in_count <= 5;
                    end
                    56: begin
                        in_count <= 6;
                    end
                    57: begin
                        in_count <= 7;
                    end
                    58: begin
                        in_count <= 8; 
                    end
                    default: begin
                        in_count <= 9;
                    end
                endcase 
            end else begin
                in_count <= in_count;
            end
        end
    end
    
    // PRE
    always @(posedge clk) begin
        if (reset) begin
            
            
        end
    end


    // Execute
    always @(posedge clk) begin
        if (rst == 0) begin
            M1_W_data <= 32'b0;
            M1_addr <= 32'b0;
            M0_W_req <= 4'b0;
            for (i = 0; i < 9; i = i + 1) begin
                Reg_result[i] <= 0;
            end
            Reg_count_fin <= 64'b0;
            done_state <= 1'b0;
        end else begin
            if (already_weight == 1'b1 && already_bias == 1'b1) begin
                case (curr_state)
                    PRE: begin
                        Reg_count_fin <= 64'b0;
                        for (i = 0; i < 9; i = i + 1) begin
                        Reg_result[i] <= 0;    
                        end
                        M1_addr <= 32'b0;
                        if (start_conv == 1'b1) begin
                            done_state[`PRE] <= 1'b1; 
                        end else begin
                            done_state <= done_state;
                        end
                    end

                    SET: begin
                        for (i = 0; i < 9; i = i + 1) begin
                            Reg_result[i] <= 32'b0; 
                        end
                        Reg_count_fin <= 64'b0;
                        if(check == 1'b1) begin
                            M1_addr <= M1_addr + 4;
                            check <= 1'b0;
                        end else begin
                            M1_addr <= M1_addr;
                            check <= check;
                        end
                        M1_W_req <= 0;
                        M1_R_req <= 0;
                        done_state[`SET] <= 1'b1;
                    end

                    READ: begin
                        if (my_addr % 28 != 26) begin
                            if (in_count < 8) begin
                                check <= check;
                                Reg_input[in_count] <= M0_R_data;
                                done_state <= done_state;
                            end else begin
                                check <= 1'b1;
                                Reg_input[in_count] <= M0_R_data;
                                done_state[`READ] <= 1'b1;
                            end
                        end else begin
                            done_state <= done_state;
                        end
                    end

                    MULT: begin
                        for (i = 0; i <= 8; i = i + 1) begin
                            Reg_mult[i] <= {{32{Reg_input[i][31]}}, Reg_input[i]} * {{32{Reg_weight[i][31]}}, Reg_weight[i]};
                        end
                        done_state[`MULT] <= 1'b1;
                    end

                    ROUND: begin
                        for (i = 0; i <= 8; i = i + 1) begin
                            if (Reg_mult[i][15:0] >= 16'b1000000000000000) begin
                                Reg_result[i] <= {Reg_mult[i][47:16]} + 32'b1;
                            end else begin
                                Reg_result[i] <= {Reg_mult[i][47:16]} + 32'b0;      
                            end
                        end
                        done_state[`ROUND] <= 1'b1;;
                    end

                    ADD: begin
                        Reg_count_fin <= {{32{Reg_result[0][31]}}, Reg_result[0]} + {{32{Reg_result[1][31]}}, Reg_result[1]} + {{32{Reg_result[2][31]}}, Reg_result[2]}
                        + {{32{Reg_result[3][31]}}, Reg_result[3]} + {{32{Reg_result[4][31]}}, Reg_result[4]} + {{32{Reg_result[5][31]}}, Reg_result[5]}
                        + {{32{Reg_result[6][31]}}, Reg_result[6]} + {{32{Reg_result[7][31]}}, Reg_result[7]} + {{32{Reg_result[8][31]}}, Reg_result[8]}
                        + {{32{Reg_bias[31]}}, Reg_bias};
                        done_state[`ADD] <= 1'b1;;
                    end
                    
                    WRITE: begin
                        if(check == 1'b1) begin
                            M1_W_req <= 4'b1111;
                            M1_R_req <= 1;
                            M1_W_data <= {Reg_count_fin[31:0]};
                        end else begin
                            M1_W_req <= M1_W_req;
                            M1_R_req <= M1_R_req;
                        end
                        done_state[`WRITE] <= 1'b1;;
                    end

                    default: begin
                        done_state <= 1'b0;
                    end

                endcase 
            end
        end
    end

    endmodule
