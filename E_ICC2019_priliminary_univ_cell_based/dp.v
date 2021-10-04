module dp(reset, clk, M0_R_req, M0_addr, M0_R_data, M0_W_req, M0_W_data, 
M1_R_req, M1_addr, M1_R_data, M1_W_req, M1_W_data, start, finish, cmd_flags);
    input         reset;
    input         clk;
    input  [31:0] M0_R_data;
    input  [31:0] M1_R_data;     //use or not
    input         start;
    input         cmd_flags;

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
    // reg [31:0] M1_addr;

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
    reg [`CNT_W-1:0] cnt;

    reg [15:0] s_addr;

    
    
    //I'd like to know whether it's better or not.
    reg signed [15:0] M1_addr_r;
    assign M1_addr = $signed(M1_addr_r);
    //I'd like to know whether it's better or not.



    parameter PRE = 3'b000, SET = 3'b001, READ = 3'b010, MULT = 3'b011, ROUND = 3'b100, ADD = 3'b101, WRITE = 3'b110;
    
    // assign my_addr = s_addr;

    // M0_W_data
    always @(posedge clk) begin
    	if (reset == 0) begin
	        M0_W_data <= 32'b0;
        end else begin
	        M0_W_data <= M0_W_data;
	    end
    end

    // read_weight
    always @(posedge clk) begin
        if (reset == 0) begin
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
        if (reset == 0) begin
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
        if (reset == 0) begin
            for (i = 0; i < 9; i = i + 1) begin
                Reg_weight[i] <= 32'b0;
            end
        end else begin
            if (M0_R_req == 1 && start_read == 1'b1 && already_weight == 1'b0) begin
                Reg_weight[((M0_addr - 4) >> 2) - 784] <= M0_R_data;
            end else begin
                for (i = 0; i < 9; i = i + 1) begin
                    Reg_weight[i] <= Reg_weight[i];
                end
            end
        end
    end

    // read Bias
    always @(posedge clk) begin
        if (reset == 0) begin
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
        if (reset == 0) begin
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
        if (reset == 0) begin
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
        if (reset == 0) begin
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
        if (reset == 0) begin
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
        if (reset == 0) begin
            finish <= 0;
        end else begin
            if (s_addr > 28 * 26 - 1) begin
                finish <= 1;
            end else begin
                finish <= finish;
            end
        end
    end

    // count M0_addr, s_addr
    always @(posedge clk) begin
        if (reset == 0) begin
            s_addr <= 32'b0;
            M0_addr <= 32'b0;
        end else begin // read weight
            if (start_read == 1'b1) begin
                if (read_weight == 1'b1) begin
                    if (already_weight == 1'b0) begin
                        if (M0_addr < 783 << 2) begin
                            M0_addr <= 783 << 2;
                            s_addr <= s_addr;
                        end else if (M0_addr > 792 << 2) begin
                            M0_addr <= M0_addr;
                            s_addr <= s_addr;
                        end else begin
                            M0_addr <= M0_addr + 4;
                            s_addr <= s_addr;
                        end
                    end else begin
                        M0_addr <= M0_addr;
                        s_addr <= s_addr;
                    end
                end else if (read_bias == 1'b1) begin
                    if (already_bias == 1'b0) begin
                        if (M0_addr < 792 * 4) begin
                            M0_addr <= 792 * 4;
                            s_addr <= s_addr;
                        end else if (M0_addr > 792 << 2) begin
                            M0_addr <= M0_addr;
                            s_addr <= s_addr;
                        end else begin
                            M0_addr <= M0_addr + 4;
                            s_addr <= s_addr;
                        end
                    end else begin
                        M0_addr <= M0_addr;
                        s_addr <= s_addr;
                    end
                end else begin
                    if (state == PRE) begin
                        s_addr <= 32'b0;
                        M0_addr <= 32'b0;
                    end else if (state == READ) begin
                        if (s_addr % 28 != 26) begin
                            if (in_count == 8) begin // to store the initial addr
                                s_addr <= s_addr + 1;
                                M0_addr <= (s_addr + 1 + count) << 2;
                            end else begin
                                s_addr <= s_addr;
                                M0_addr <= (s_addr + count) << 2;
                            end
                        end else begin
                            s_addr <= s_addr + 2;
                            M0_addr <= (s_addr + 2) << 2;
                        end
                    end else begin
                        s_addr <= s_addr;
                        M0_addr <= M0_addr;
                    end
                end 
            end 
        end
    end

    // count
    always @(posedge clk) begin
        if (reset == 0) begin
            count <= 0;
        end else begin
            if (cmd_flags[`CMD_SET]) begin
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
                        count <= count;
                    end
                endcase 
            end else begin
                count <= count;
            end
        end
    end

    // in_count
    always @(posedge clk) begin
        if (reset == 0) begin
            in_count <= 0;
        end else begin
            if (cmd_flags[`CMD_READ]) begin
                if (in_count <= 8) begin
                    in_count <= in_count + 1;
                end else begin
                    in_count <= 0;
                end
            end else begin
                in_count <= in_count;
            end
        end
    end

    // M1_addr_r
    always @(posedge clk) begin
        if (reset == 0) begin
            M1_addr_r <= 32'b0;
        end else begin
            if (cmd_flags[`CMD_SET]) begin
                if(check == 1'b1) begin
                    M1_addr_r <= M1_addr_r + 32'd4;
                end else begin
                    M1_addr_r <= M1_addr_r;
                end
            end
        end
    end

    // M1_W_req, M1_W_data, M1_R_req
    always @(posedge clk) begin
        if (reset == 0) begin
            M1_W_data <= 32'b0;
            M1_W_req <= 0;
            M1_R_req <= 0;
        end else begin
            if (cmd_flags[`CMD_SET]) begin
                M1_W_data <= {Reg_count_fin[31:0]};
                M1_W_req <= 4'b0;
                M1_R_req <= 0;
            end else begin
                if (cmd_flags[`CMD_WRITE]) begin
                    if(check == 1'b1) begin
                        M1_W_data <= {Reg_count_fin[31:0]};
                        M1_W_req <= 4'b1111;
                        M1_R_req <= 1;
                    end
                end
            end
        end
    end

    // check
    always @(posedge clk) begin
        if (reset == 0) begin
            check <= 1'b0;
        end else begin
            if (cmd_flags[`CMD_SET]) begin
                if (check == 1'b1) begin
                    check <= 1'b0;
                end else begin
                    check <= check;
                end
            end
            check <= check
        end
    end

    // M0_W_req
    always @(posedge clk) begin
        if (reset == 0) begin
            M0_W_req <= 4'b0;
        end else begin
            M0_W_req <= M0_W_req;
        end
    end

    // Reg_result
    always @(posedge clk) begin
        if (reset == 0) begin
            for (i = 0; i < 9; i = i + 1) begin
                Reg_result[i] <= 0;
            end
        end else begin
            if (cmd_flags[`CMD_ROUND]) begin
                if (Reg_mult[cnt][15:0] >= 16'b1000000000000000) begin
                    Reg_result[cnt] <= {Reg_mult[cnt][47:16]} + 32'b1;
                end else begin
                    Reg_result[cnt] <= {Reg_mult[cnt][47:16]} + 32'b0;      
                end
            end
        end
    end

    // cnt
    always @(posedge clk) begin
        if (reset == 0) begin
            cnt <= 0;
        end else begin
            if (cnt_rst == 1) begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

    // Reg_count_fin
    always @(posedge clk) begin
        if (reset == 0) begin
            Reg_count_fin <= 64'b0;
        end else begin
            if (cmd_flags[`CMD_SET]) begin
                Reg_count_fin <= 64'b0; 
            end else if (cmd_flags[`CMD_ADD]) begin
                Reg_count_fin <= Reg_count_fin + {{32{Reg_result[cnt][31]}}, Reg_result[cnt]};
            end else begin
                Reg_count_fin <= Reg_count_fin;
            end
        end 
    end

    // Execute
    always @(posedge clk) begin
        if (reset == 0) begin
            state <= PRE;
        end else begin
            if (already_weight == 1'b1 && already_bias == 1'b1) begin
                case (state)
                    SET: begin
                        state <= READ;
                    end

                    READ: begin 
                        if (s_addr % 28 != 26) begin
                            if (in_count < 8) begin
                                check <= check;
                                Reg_input[in_count] <= M0_R_data;
                                state <= SET;
                            end else begin
                                check <= 1'b1;
                                Reg_input[in_count] <= M0_R_data;
                                state <= MULT;
                            end
                        end else begin
                            state <= SET;
                        end
                    end

                    MULT: begin
                        for (i = 0; i <= 8; i = i + 1) begin
                            Reg_mult[i] <= {{32{Reg_input[i][31]}}, Reg_input[i]} * {{32{Reg_weight[i][31]}}, Reg_weight[i]};
                        end
                        state <= ROUND;
                    end

                    default: begin
                        state <= SET;
                        M1_addr_r <= 32'b0;
                    end
                endcase 
            end else begin
                for (i = 0; i < 9; i = i + 1) begin
                    Reg_result[i] <= Reg_result[i];
                end
                state <= state;
            end
        end
    end
endmodule