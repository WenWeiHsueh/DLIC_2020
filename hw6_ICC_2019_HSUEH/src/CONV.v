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

    reg [31:0] Reg_input     [8:0];
    reg [31:0] Reg_weight    [8:0];
    reg [31:0] Reg_bias;
    reg [31:0] Reg_result    [8:0];
    reg [63:0] Reg_mult      [8:0];
    reg [63:0] Reg_count_fin;
    reg [3:0]  state;
    reg [0:0]  start_conv;
    reg [0:0]  start_read;
    reg [4:0]  in_count; // the index of input data
    reg [7:0]  count; // to count the current # of data
    reg [31:0] my_addr;
    reg [0:0]  check; // to check if the input data follow the rules of convolution
    reg [3:0]  i;
    reg [11:0] pseudo_addr;
    reg [15:0] base_addr;
    reg [1:0] kernel_sel;
    reg [0:0] finish_lay0_k0;
    reg [0:0] kernel;

    reg signed [`DATA_WIDTH-1:0] w_mem [0:8];
    reg signed [`DATA_WIDTH-1:0] bias;

    parameter PRE = 4'b0000, SET = 4'b0001, READ = 4'b0010, MULT = 4'b0011, ROUND = 4'b0100, ADD = 4'b0101, RELU = 4'b0110,  WRITE = 4'b0111, KER_SWI = 4'b1000;
    
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
            end else if (iaddr > 64 * 64 - 1) begin
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
            end else begin
                start_conv <= start_conv;
            end
        end
    end

    // start_read
    always @(posedge clk) begin
        if(ready == 1'b1) begin
            start_read <= 1'b1;
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
            csel <= kernel == 0 ? 3'b001 : 3'b010;
        end
    end

    // iaddr
    always @(posedge clk) begin
        if (reset) begin
            base_addr <= 32'b0;
            pseudo_addr <= 0;
        end else begin
            if (state == READ) begin
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

    // count
    always @(posedge clk) begin
        if (reset == 1'b1) begin
            count <= 0;
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
            end else begin
                count <= count;
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
                        if ((base_addr % 66 != 64) && (base_addr % 66 != 65)) begin
                            Reg_input[in_count] <= data;
                            if (in_count < 8) begin
                                check <= check;
                                state <= SET;
                            end else begin
                                check <= 1'b1;
                                state <= MULT;
                            end
                        end
                    end

                    MULT: begin // 3
                        for (i = 0; i <= 8; i = i + 1) begin
                            Reg_mult[i] <= {{32{Reg_input[i][19]}}, Reg_input[i]} * {{32{w_mem[i][19]}}, w_mem[i]};
                        end                 
                        state <= ROUND;
                    end

                    ROUND: begin // 4
                        for (i = 0; i <= 8; i = i + 1) begin
                            if (Reg_mult[i][15:0] >= 16'b1000000000000000) begin
                                Reg_result[i] <= {Reg_mult[i][47:16]} + 32'b1;
                            end else begin
                                Reg_result[i] <= {Reg_mult[i][47:16]} + 32'b0;      
                            end
                        end
                        state <= ADD;
                    end

                    ADD: begin // 5
                        Reg_count_fin <= {{32{Reg_result[0][19]}}, Reg_result[0]} + {{32{Reg_result[1][19]}}, Reg_result[1]} + {{32{Reg_result[2][19]}}, Reg_result[2]}
                        + {{32{Reg_result[3][19]}}, Reg_result[3]} + {{32{Reg_result[4][19]}}, Reg_result[4]} + {{32{Reg_result[5][19]}}, Reg_result[5]}
                        + {{32{Reg_result[6][19]}}, Reg_result[6]} + {{32{Reg_result[7][19]}}, Reg_result[7]} + {{32{Reg_result[8][19]}}, Reg_result[8]}
                        + {{32{bias[19]}}, bias};
                        state <= RELU;
                    end

                    RELU: begin // 6
                        Reg_count_fin <= ((Reg_count_fin[63] == 0) ? Reg_count_fin : 0);
                        state <= WRITE;
                    end

                    WRITE: begin // 7
                        if(check == 1'b1) begin
                            cwr <= 1'b1;
                            cdata_wr <= {Reg_count_fin[31:0]};
                        end
                        if (kernel == 0) begin
                            kernel <= 1;
                            state <= KER_SWI;
                        end else if (kernel == 1) begin
                            state <= SET;
                        end
                    end

                    KER_SWI: begin // 8 Waiting for kernel switch
                        state <= MULT;
                    end

                endcase 
            end
        end
    end
endmodule
