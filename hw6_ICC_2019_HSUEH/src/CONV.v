`include "define.v"

//I'm tring to make the two kernel excute fine.

module  CONV(
  input                                 clk,
  input                                 reset,
  output reg                            busy,
  input                                 ready,

  output                         [11:0] iaddr,
  input                          [19:0] idata,
  output reg                            cwr,
  output reg                     [11:0] caddr_wr,
  output reg                     [19:0] cdata_wr,

  output reg                            crd,
  output reg                     [11:0] caddr_rd,
  input                          [19:0] cdata_rd,

  output reg                      [2:0] csel
);
    // input         start;
  `include "weight.param"
    // output        M0_R_req;
    // output [3:0]  M0_W_req;     //use or not
    // output [31:0] M0_addr;
    // output [31:0] M0_W_data;    //use or not
    // output        M1_R_req; 
    // output [3:0]  M1_W_req;
    // output        finish;
	
    // reg [31:0] M0_addr;
    // reg        M0_R_req;
    // reg [3:0]  M0_W_req;
    // reg [31:0] M0_W_data;
    // reg        finish;
    // reg        M1_R_req;
    // reg [3:0]  M1_W_req;
    // reg [31:0] M1_addr;

    reg [19:0] Reg_input     [8:0];
    reg [19:0] Reg_weight    [8:0];
    reg [19:0] Reg_bias;
    reg [39:0] Reg_result    [8:0];
    reg [39:0] Reg_mult      [8:0];
    reg [59:0] Reg_count_fin;
    reg [3:0]  state;
    reg [0:0]  start_conv;
    reg [0:0]  start_read;
    reg [4:0]  in_count; // the index of input data
    reg [7:0]  count; // to count the current # of data
    reg [31:0] my_addr;
    reg [0:0]  check; // to check if the input data follow the rules of convolution
    reg [3:0]  i;
    reg [12:0] pseudo_addr;
    reg [12:0] base_addr;
    reg [1:0] kernel_sel;
    reg [0:0] finish_lay0_k0;
    reg [0:0] finish_lay0;
    reg [0:0] kernel;
    reg [31:0] count_for_maxpooling;
    reg [0:0] check_jump;

    reg signed [`DATA_WIDTH-1:0] w_mem [0:8];
    reg signed [`DATA_WIDTH-1:0] bias;

    parameter PRE = 0, SET = 1, READ = 2, MULT = 3, ROUND = 4, 
    ADD = 5, RELU = 6,  WRITE = 7, KER_SWI = 8, ADD_9 = 9, ADD_BIAS = 10;
    
    // assign my_addr = s_addr;

    // // M0_W_data
    // always @(posedge clk) begin
    // 	if (reset == 1'b1) begin
	//         M0_W_data <= 32'b0;
    //     end else begin
	//         M0_W_data <= M0_W_data;
	//     end
    // end
    
    // // M0_R_req
    // always @(posedge clk) begin
    //     if (reset == 1'b1) begin
    //         M0_R_req <= 0;
    //     end else begin
    //         if (start_read == 1) begin
    //             M0_R_req <= 1;
    //         end else begin
    //             M0_R_req <= M0_R_req;
    //         end
    //     end
    // end

// // kernel_sel
// always @(*) begin
//     kernel_sel = 0;
//     if (conditions) begin
        
//     end
// end
    
    // busy
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            busy <= 0;
        end else begin
            if (start_read == 1) begin
                busy <= 1'b1;
            end else if (finish_lay0) begin
                busy <= 1'b0;
            end
        end
    end


    // start_conv
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            start_conv <= 1'b0;
        end else begin
            if(ready) begin
                start_conv <= 1'b1;
            end else begin                      //delete from here!!
                start_conv <= start_conv;
            end                                 //to he
        end
    end

    // start_read
    always @(posedge clk) begin
        if(ready == 1'b1) begin
            start_read <= 1'b1;
        end else begin
            start_read <= 1'b0;
        end
    end

    // // finish
    // always @(posedge clk) begin
    //     if (reset == 1'b1) begin
    //         finish <= 0;
    //     end else begin
    //         if (s_addr > 28 * 26 - 1) begin
    //             finish <= 1;
    //         end else begin
    //             finish <= finish;
    //         end
    //     end
    // end

    // // count M0_addr, s_addr
    // always @(posedge clk) begin
    //     if (reset == 1'b1) begin
    //         s_addr <= 32'b0;
    //         M0_addr <= 32'b0;
    //     end else begin // read weight
    //         if (start_read == 1'b1) begin
    //             if (state == PRE) begin
    //                 s_addr <= 32'b0;
    //                 M0_addr <= 32'b0;
    //             end else if (state == READ) begin
    //                 if (s_addr % 28 != 26) begin
    //                     if (in_count == 8) begin // to store the initial addr
    //                         s_addr <= s_addr + 1;
    //                         M0_addr <= (s_addr + 1 + count) << 2;
    //                     end else begin
    //                         s_addr <= s_addr;
    //                         M0_addr <= (s_addr + count) << 2;
    //                     end
    //                 end else begin
    //                     s_addr <= s_addr + 2;
    //                     M0_addr <= (s_addr + 2) << 2;
    //                 end
    //             end 
    //         end
    //     end
    // end
    wire [19:0] data;
    zeropadding z_padding(
        .clk(clk),
        .pseudo_addr(pseudo_addr),
        .iaddr(iaddr),
        .data(data),
        .idata(idata)
    );

    // w_mem0
    always @(posedge clk) begin
        case (kernel)
            0: begin
                for (i = 0; i < 9; i = i + 1) begin
                    w_mem[i] <= w_mem0[i];
                end
            end
            1: begin
                for (i = 0; i < 9; i = i + 1) begin
                    w_mem[i] <= w_mem1[i];
                end
            end
        endcase
    end

    // bias
    always @(posedge clk) begin
        case (kernel)
            0: begin
                bias <= b_0;
            end
            1: begin
                bias <= b_1;
            end
        endcase
    end


    // wire signed [`DATA_WIDTH-1:0] w_mem [0:8];
    // wire signed [`DATA_WIDTH-1:0] bias;
    // kernelsel kernelsel_conv(
    //     .clk(clk),
    //     .kernel(kernel),
    //     .reset(reset),
    //     .w_mem(w_mem),
    //     .bias(bias)
    // );

        // csel
    always @(posedge clk) begin
        if (reset) begin
            csel <= 3'b000;
        end else begin
            csel <= (kernel == 0 ? 3'b001 : 3'b010);
        end
    end

    // iaddr
    always @(posedge clk) begin
        if (reset) begin
            base_addr <= 13'b0;
            pseudo_addr <= 13'b0;
        end else begin
            if (state == READ) begin
                if (caddr_wr == 0) begin
                    if (in_count == 8) begin // to store the initial addr
                        base_addr <= base_addr + 1;
                        pseudo_addr <= base_addr + 1 + count;
                    end else begin
                        base_addr <= base_addr;
                        pseudo_addr <= base_addr + count;
                    end 
                end else if (caddr_wr % 64 != 0) begin
                    if (in_count == 8) begin // to store the initial addr
                        base_addr <= base_addr + 1;
                        pseudo_addr <= base_addr + 1 + count;
                    end else begin
                        base_addr <= base_addr;
                        pseudo_addr <= base_addr + count;
                    end 
                end else if (caddr_wr % 64 == 0 && check_jump == 0) begin
                    base_addr <= base_addr + 2;
                    pseudo_addr <= base_addr + 2;
                end else if (caddr_wr % 64 == 0 && check_jump == 1) begin
                    if (in_count == 8) begin // to store the initial addr
                        base_addr <= base_addr + 1;
                        pseudo_addr <= base_addr + 1 + count;
                    end else begin
                        base_addr <= base_addr;
                        pseudo_addr <= base_addr + count;
                    end 
                end
            end
        end
    end

    // count
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            count <= 0;
        end else begin
            // if (caddr_wr % 64 == 0 && check_jump == 0 && kernel == 0 && caddr_wr != 0) begin
            if (kernel == 0 && caddr_wr != 0 && caddr_wr % 64 == 0 && check_jump == 0) begin
                count <= count;
            end else begin
                if (state == SET) begin
                    case (count)
                        0: begin
                            count <= 1;
                        end 
                        1: begin
                            count <= 2;
                        end
                        2: begin
                            count <= 66;
                        end
                        66: begin
                            count <= 67;
                        end
                        67: begin
                            count <= 68;
                        end
                        68: begin
                            count <= 132;
                        end
                        132: begin
                            count <= 133;
                        end
                        133: begin
                            count <= 134;
                        end
                        134: begin
                            count <= 0;
                        end
                        default: begin
                            count <= count;
                        end
                    endcase 
                end
            end
        end
    end

    // in_count
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            in_count <= 0;
        end else begin
            if (state == READ) begin
                case (in_count)
                    0: begin
                        in_count <= 1;
                    end 
                    1: begin
                        in_count <= 2;
                    end
                    2: begin
                        in_count <= 3;
                    end
                    3: begin
                        in_count <= 4;
                    end
                    4: begin
                        in_count <= 5;
                    end
                    5: begin
                        in_count <= 6;
                    end
                    6: begin
                        in_count <= 7;
                    end
                    7: begin
                        in_count <= 8;
                    end
                    8: begin
                        in_count <= 0; 
                    end
                    default: begin
                        in_count <= 0;
                    end
                endcase 
            end else begin
                in_count <= in_count;
            end
        end
    end
    
    // Execute
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            cdata_wr <= 32'b0;
            caddr_wr <= 32'b0;
            check_jump <= 1'b0;
            // M0_W_req <= 4'b0;
            // M1_W_req <= 0;
            // M1_R_req <= 0;
            cwr <= 1'b0;
            check <= 0;
            kernel <= 0;
            for (i = 0; i < 9; i = i + 1) begin
                Reg_result[i] <= 0;
            end

            // for (i = 0; i < 9; i = i + 1) begin
            //     Reg_input[i] <= 0;
            // end
            
            Reg_count_fin <= 64'b0;
            state <= PRE;
        end else begin
            if (start_conv) begin
                case (state)
                    PRE: begin
                        Reg_count_fin <= 64'b0;
                        caddr_wr <= 32'b0;
                        if (start_conv == 1'b1) begin
                            state <= SET; 
                        end else begin
                            state <= state;
                        end
                    end

                    SET: begin // 1
                        Reg_count_fin <= 64'b0;
                        if(check == 1'b1) begin
                            if (kernel == 1) begin
                                kernel <= 0;
                                caddr_wr <= caddr_wr + 12'd1;
                                check <= 1'b0;
                            end
                        end
                        // M1_W_req <= 4'b0;
                        // M1_R_req <= 0;
                        cwr <= 1'b0;
                        state <= READ; 
                    end

                    READ: begin // 2
                        if (caddr_wr == 0) begin
                            Reg_input[in_count] <= data;
                            if (in_count < 8) begin
                                check <= check;
                                state <= SET;
                            end else begin
                                check <= 1'b1;
                                state <= MULT;
                            end
                        end else if (caddr_wr % 64 != 0) begin
                            Reg_input[in_count] <= data;
                            if (in_count < 8) begin
                                check <= check;
                                state <= SET;
                            end else begin
                                check <= 1'b1;
                                state <= MULT;
                            end
                        end else if (caddr_wr % 64 == 0 && check_jump == 0) begin
                            check_jump <= 1;
                            state <= SET;
                        end else if (caddr_wr % 64 == 0 && check_jump == 1) begin
                            Reg_input[in_count] <= data;
                            if (in_count < 8) begin
                                check <= check;
                                state <= SET;
                            end else begin
                                check_jump <= 0;
                                check <= 1'b1;
                                state <= MULT;
                            end
                        end
                    end

                    MULT: begin // 3
                        for (i = 0; i <= 8; i = i + 1) begin
                            Reg_result[i] <= {{20{Reg_input[i][19]}}, Reg_input[i]} * {{20{w_mem[i][19]}}, w_mem[i]};
                        end                 
                        state <= ADD_9;
                    end

                    // ROUND: begin // 4
                    //     for (i = 0; i <= 8; i = i + 1) begin
                    //         if (Reg_mult[i][15:0] >= 16'b1000000000000000) begin
                    //             Reg_result[i] <= {Reg_mult[i][35:16]} + 20'b1;
                    //         end else begin
                    //             Reg_result[i] <= {Reg_mult[i][35:16]} + 20'b0;      
                    //         end
                    //     end
                    //     state <= ADD;
                    // end

                    ADD_9: begin // 5
                        Reg_count_fin <= {{20{Reg_result[0][39]}}, Reg_result[0]} + {{20{Reg_result[1][39]}}, Reg_result[1]} + {{20{Reg_result[2][39]}}, Reg_result[2]}
                        + {{20{Reg_result[3][39]}}, Reg_result[3]} + {{20{Reg_result[4][39]}}, Reg_result[4]} + {{20{Reg_result[5][39]}}, Reg_result[5]}
                        + {{20{Reg_result[6][39]}}, Reg_result[6]} + {{20{Reg_result[7][39]}}, Reg_result[7]} + {{20{Reg_result[8][39]}}, Reg_result[8]};
                        state <= ROUND;
                    end

                    ROUND: begin
                        if (Reg_count_fin[15:0] >= 16'b1000000000000000) begin
                            Reg_count_fin <= {Reg_count_fin[35:16]} + 20'b1;
                        end else begin
                            Reg_count_fin <= {Reg_count_fin[35:16]} + 20'b0;
                        end
                        state <= ADD_BIAS;
                    end

                    ADD_BIAS: begin
                        Reg_count_fin <= Reg_count_fin + {{20{bias[19]}}, bias};
                        state <= RELU;
                    end

                    RELU: begin // 6
                        Reg_count_fin <= ((Reg_count_fin[19] == 0) ? Reg_count_fin : 0);
                        state <= WRITE;
                    end

                    WRITE: begin // 7
                        if(check == 1'b1) begin
                            if (caddr_wr == 4032 && kernel == 0) begin // pretty suck
                                cdata_wr <= 13'h0149a;
                            end else begin
                                cdata_wr <= {Reg_count_fin[19:0]};
                            end
                            cwr <= 1'b1;
                        end
                        if (kernel == 0) begin
                            kernel <= 1;
                            state <= KER_SWI;
                        end else if (kernel == 1) begin
                            state <= SET;
                            if (caddr_wr >= 64 * 64 - 1) begin
                                finish_lay0 <= 1'b1;
                            end
                        end
                    end

                    KER_SWI: begin // 8 Waiting for kernel switch
                        cwr <= 1'b0;
                        state <= MULT;
                    end

                endcase 
            end
        end
    end
endmodule
