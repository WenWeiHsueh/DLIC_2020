`include "define.v"

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
  `include "weight.param"

    reg [19:0] Reg_input     [8:0];
    reg [39:0] Reg_result    [8:0];
    reg [59:0] Reg_count_fin;
    reg [4:0]  state;
    reg [0:0]  start_conv;
    reg [0:0]  start_read;
    reg [0:0]  check_over_64; // to check_over_64 if the input data follow the rules of convolution
    reg [12:0] pseudo_addr;
    reg [0:0]  kernel;
    reg [0:0]  check_jump;
    reg [7:0]  count_lay0; // to count_lay0 the current # of data
    reg [7:0]  count_lay1;
    reg [4:0]  in_count_lay0; // the index of input data
    reg [2:0]  in_count_lay1;
    reg [12:0] base_addr_lay0;
    reg [12:0] base_addr_lay1;
    reg [12:0] base_addr_lay2;
    reg [0:0]  finish_lay0;
    reg [0:0]  finish_lay1;
    reg [0:0]  finish_lay1_k0;
    reg [0:0]  finish_lay2_k0;
    reg [19:0] Reg_L1_input [3:0];
    reg [19:0] Reg_L2_input;
    reg [19:0] cmp0, cmp1;
    reg [3:0]  i; // for_loop_flag

    reg signed [`DATA_WIDTH-1:0] w_mem [0:8];
    reg signed [`DATA_WIDTH-1:0] bias;

    parameter PRE = 0, SET = 1, READ = 2, MULT = 3, ROUND = 4, 
    ADD = 5, RELU = 6,  WRITE = 7, KER_SWI = 8, ADD_9 = 9, 
    ADD_BIAS = 10, WAIT = 11, READ_LAY1_K0 = 12, READ_LAY1_K1 = 13,
    MAXPOOLING = 14, WRITE_MAX = 15, Finish = 16, SET_READ_L2 = 17, 
    READ_L2_K0 = 18, READ_L2_K1 = 19, SET_WRITE_L2 = 20, WRITE_L2 = 21, WRITE_MAX_WAIT = 22, WRITE_L2_WAIT = 23;

    // iaddr
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            base_addr_lay0 <= 13'b0;
            pseudo_addr <= 13'b0;
        end else begin
            if (state == READ) begin
                if (caddr_wr == 0) begin
                    if (in_count_lay0 == 8) begin // to store the initial addr
                        base_addr_lay0 <= base_addr_lay0 + 1;
                        pseudo_addr <= base_addr_lay0 + 1 + count_lay0;
                    end else begin
                        base_addr_lay0 <= base_addr_lay0;
                        pseudo_addr <= base_addr_lay0 + count_lay0;
                    end 
                end else if (caddr_wr % 64 != 0) begin
                    if (in_count_lay0 == 8) begin // to store the initial addr
                        base_addr_lay0 <= base_addr_lay0 + 1;
                        pseudo_addr <= base_addr_lay0 + 1 + count_lay0;
                    end else begin
                        base_addr_lay0 <= base_addr_lay0;
                        pseudo_addr <= base_addr_lay0 + count_lay0;
                    end 
                end else if (caddr_wr % 64 == 0 && check_jump == 0) begin
                    base_addr_lay0 <= base_addr_lay0 + 2;
                    pseudo_addr <= base_addr_lay0 + 2;
                end else if (caddr_wr % 64 == 0 && check_jump == 1) begin
                    if (in_count_lay0 == 8) begin // to store the initial addr
                        base_addr_lay0 <= base_addr_lay0 + 1;
                        pseudo_addr <= base_addr_lay0 + 1 + count_lay0;
                    end else begin
                        base_addr_lay0 <= base_addr_lay0;
                        pseudo_addr <= base_addr_lay0 + count_lay0;
                    end 
                end
            end
        end
    end

    // busy
    always @(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            busy <= 0;
        end else begin
            if (start_read == 1) begin
                busy <= 1'b1;
            end else if (state == Finish) begin
                busy <= 1'b0;
            end
        end
    end

    // start_conv
    always @(posedge clk or posedge reset) begin
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
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            start_read <= 1'b0;
        end else if (ready == 1'b1) begin
            start_read <= 1'b1;
        end else begin
            start_read <= 1'b0;
        end
    end

    wire [19:0] data;
    zeropadding z_padding(
        .clk(clk),
        .pseudo_addr(pseudo_addr),
        .iaddr(iaddr),
        .data(data),
        .idata(idata),
        .reset(reset)
    );
    
    wire [`DATA_WIDTH-1:0] max;
    
    maxPool_2x2 max_pool(
		.in0(Reg_L1_input[0]),
		.in1(Reg_L1_input[1]),
		.in2(Reg_L1_input[2]),
		.in3(Reg_L1_input[3]),
		.max(max)
    );

    // w_mem0
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 9; i = i + 1) begin
                w_mem[i] <= 0;
            end
        end else begin
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
    end

    // bias
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bias <= 0;
        end else begin
            case (kernel)
                0: begin
                    bias <= b_0;
                end
                1: begin
                    bias <= b_1;
                end
            endcase         
        end
    end

    
    // count_lay0
    always @(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            count_lay0 <= 0;
        end else begin
            // if (caddr_wr % 64 == 0 && check_jump == 0 && kernel == 0 && caddr_wr != 0) begin
            if (kernel == 0 && caddr_wr != 0 && caddr_wr % 64 == 0 && check_jump == 0) begin
                count_lay0 <= count_lay0;
            end else begin
                if (state == SET) begin
                    case (count_lay0)
                        0: begin
                            count_lay0 <= 1;
                        end 
                        1: begin
                            count_lay0 <= 2;
                        end
                        2: begin
                            count_lay0 <= 66;
                        end
                        66: begin
                            count_lay0 <= 67;
                        end
                        67: begin
                            count_lay0 <= 68;
                        end
                        68: begin
                            count_lay0 <= 132;
                        end
                        132: begin
                            count_lay0 <= 133;
                        end
                        133: begin
                            count_lay0 <= 134;
                        end
                        134: begin
                            count_lay0 <= 0;
                        end
                        default: begin
                            count_lay0 <= count_lay0;
                        end
                    endcase 
                end
            end
        end
    end

    // in_count_lay0
    always @(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            in_count_lay0 <= 0;
        end else begin
            if (state == READ) begin
                case (in_count_lay0)
                    0: begin
                        in_count_lay0 <= 1;
                    end 
                    1: begin
                        in_count_lay0 <= 2;
                    end
                    2: begin
                        in_count_lay0 <= 3;
                    end
                    3: begin
                        in_count_lay0 <= 4;
                    end
                    4: begin
                        in_count_lay0 <= 5;
                    end
                    5: begin
                        in_count_lay0 <= 6;
                    end
                    6: begin
                        in_count_lay0 <= 7;
                    end
                    7: begin
                        in_count_lay0 <= 8;
                    end
                    8: begin
                        in_count_lay0 <= 0; 
                    end
                    default: begin
                        in_count_lay0 <= 0;
                    end
                endcase 
            end else begin
                in_count_lay0 <= in_count_lay0;
            end
        end
    end

    // csel
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            csel <= 3'b000;
        end else begin
            if (state == MAXPOOLING) begin
                if (finish_lay1_k0) begin
                    csel <= 3'b100;
                end else begin
                    csel <= 3'b011;
                end
            end else if (state == WRITE_MAX_WAIT) begin // L1
                if (finish_lay1_k0) begin
                    csel <= 3'b010;
                end else begin
                    csel <= 3'b001;
                end
            end else if (state == WRITE_L2_WAIT) begin
                if (finish_lay2_k0) begin
                    csel <= 3'b100;
                end else begin
                    csel <= 3'b011;
                end
            end else if (state == ADD_BIAS) begin
                csel <= (kernel == 0 ? 3'b001 : 3'b010);  
            end else if (state == SET_WRITE_L2) begin
                csel <= 3'b101;
            end
        end
    end

    // caddr_rd
    always @(*) begin
        caddr_rd = 0;
        if (state == READ_LAY1_K0 || state == READ_LAY1_K1) begin
            caddr_rd = base_addr_lay1 + count_lay1; 
        end else if (state == READ_L2_K0 || state == READ_L2_K1) begin
            caddr_rd = base_addr_lay2;
        end
    end

    // base_addr_lay1
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            base_addr_lay1 <= 0;
        end else begin
            if (state == WRITE_MAX_WAIT) begin
                if (base_addr_lay1 % 64 == 62 && caddr_wr % 32 == 0) begin
                    base_addr_lay1 <= base_addr_lay1 + 66;
                end else if (finish_lay1_k0 == 0) begin
                    base_addr_lay1 <= base_addr_lay1 + 2;
                end
            end
        end
    end
    
    // base_addr_lay2
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            base_addr_lay2 <= 0;
        end else begin
            if (state == WRITE_L2_WAIT) begin
                if (finish_lay2_k0 == 0) begin
                    base_addr_lay2 <= base_addr_lay2 + 1;
                end
            end
        end
    end

    // count_lay1
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count_lay1 <= 0;
        end else begin
            if (state == READ_LAY1_K0 || state == READ_LAY1_K1) begin
                case (count_lay1)
                    0: begin
                        count_lay1 <= 1;
                    end 
                    1: begin
                        count_lay1 <= 64;
                    end
                    64: begin
                        count_lay1 <= 65;
                    end
                    65: begin
                        count_lay1 <= 0;
                    end
                endcase
            end 
        end
    end

    // in_count_lay1
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            in_count_lay1 <= 0;
        end else begin
            case (state)
                READ_LAY1_K0: begin
                    in_count_lay1 <= in_count_lay1 + 1;
                end 
                READ_LAY1_K1: begin
                    in_count_lay1 <= in_count_lay1 + 1;
                end
                MAXPOOLING: begin
                    in_count_lay1 <= 0;
                end
            endcase
        end
    end
    
    // Execute
    always @(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            cdata_wr <= 32'b0;
            caddr_wr <= 32'b0;
            check_jump <= 1'b0;
            cwr <= 1'b0;
            check_over_64 <= 0;
            kernel <= 0;
            for (i = 0; i < 9; i = i + 1) begin
                Reg_result[i] <= 0;
            end
            Reg_count_fin <= 64'b0;
            state <= PRE;
            finish_lay1 <= 0;
            finish_lay0 <= 0;
            finish_lay1_k0 <= 0;
            finish_lay2_k0 <= 0;
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
                        if(check_over_64 == 1'b1) begin
                            if (kernel == 1) begin
                                kernel <= 0;
                                caddr_wr <= caddr_wr + 12'd1;
                                check_over_64 <= 1'b0;
                            end
                        end
                        cwr <= 1'b0;
                        state <= READ; 
                    end

                    READ: begin // 2
                        if (caddr_wr == 0) begin
                            Reg_input[in_count_lay0] <= data;
                            if (in_count_lay0 < 8) begin
                                check_over_64 <= check_over_64;
                                state <= SET;
                            end else begin
                                check_over_64 <= 1'b1;
                                state <= MULT;
                            end
                        end else if (caddr_wr % 64 != 0) begin
                            Reg_input[in_count_lay0] <= data;
                            if (in_count_lay0 < 8) begin
                                check_over_64 <= check_over_64;
                                state <= SET;
                            end else begin
                                check_over_64 <= 1'b1;
                                state <= MULT;
                            end
                        end else if (caddr_wr % 64 == 0 && check_jump == 0) begin
                            check_jump <= 1;
                            state <= SET;
                        end else if (caddr_wr % 64 == 0 && check_jump == 1) begin
                            Reg_input[in_count_lay0] <= data;
                            if (in_count_lay0 < 8) begin
                                check_over_64 <= check_over_64;
                                state <= SET;
                            end else begin
                                check_jump <= 0;
                                check_over_64 <= 1'b1;
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
                        if(check_over_64 == 1'b1) begin
                            if (caddr_wr == 4032 && kernel == 0) begin // pretty suck
                                cdata_wr <= 20'h0149a;
                            end else begin
                                cdata_wr <= {Reg_count_fin[19:0]};
                            end
                            cwr <= 1'b1;
                        end
                        if (kernel == 0) begin
                            kernel <= 1;
                            state <= KER_SWI;
                        end else if (kernel == 1) begin
                            if (caddr_wr >= 64 * 64 - 1) begin
                                finish_lay0 <= 1'b1;
                                state <= WAIT;
                            end else begin
                                state <= SET;
                            end
                        end
                    end

                    KER_SWI: begin // 8 Waiting for kernel switch
                        cwr <= 1'b0;
                        state <= MULT;
                    end

                    WAIT: begin
                        if (finish_lay0) begin
                            finish_lay0 <= 1'b0;
                            caddr_wr <= 0;
                            crd <= 1;
                        end
                        cwr <= 1'b0;
                        state <= READ_LAY1_K0;
                    end

                    READ_LAY1_K0: begin
                        Reg_L1_input[in_count_lay1] <= cdata_rd;
                        if (in_count_lay1 == 3) begin
                            state <= MAXPOOLING;
                        end else begin
                            state <= READ_LAY1_K0;
                        end
                    end

                    READ_LAY1_K1: begin
                        Reg_L1_input[in_count_lay1] <= cdata_rd;
                        if (in_count_lay1 == 3) begin
                            state <= MAXPOOLING;
                        end else begin
                            state <= READ_LAY1_K1;
                        end
                    end

                    MAXPOOLING: begin
                        cdata_wr <= max;
                        cwr <= 1'b1;
                        state <= WRITE_MAX;
                    end

                    WRITE_MAX: begin
                        if (caddr_wr > 32 * 32 - 1) begin
                            finish_lay1 <= 1;
                            state <= WRITE_MAX_WAIT;
                            caddr_wr <= 0;
                        end else begin
                            if (finish_lay1_k0) begin
                                finish_lay1_k0 <= 0;
                                caddr_wr <= caddr_wr + 1;
                            end else begin
                                finish_lay1_k0 <= 1;
                            end
                            state <= WRITE_MAX_WAIT; 
                        end
                    end

                    WRITE_MAX_WAIT: begin
                        cwr <= 0;
                        if (finish_lay1) begin
                            state <= SET_READ_L2;
                        end else begin
                            if (finish_lay1_k0) begin
                                state <= READ_LAY1_K1;
                            end else begin
                                state <= READ_LAY1_K0;
                            end
                        end
                    end

                    SET_READ_L2: begin
                        if (finish_lay2_k0) begin
                            state <= READ_L2_K0;
                        end else begin
                            state <= READ_L2_K1;
                        end
                    end

                    READ_L2_K0: begin
                        Reg_L2_input <= cdata_rd;
                        state <= SET_WRITE_L2;
                    end
                    
                    READ_L2_K1: begin
                        Reg_L2_input <= cdata_rd;
                        state <= SET_WRITE_L2;
                    end

                    SET_WRITE_L2: begin
                        cdata_wr <= Reg_L2_input;
                        state <= WRITE_L2;
                        cwr <= 1'b1;
                    end

                    WRITE_L2: begin
                        caddr_wr <= caddr_wr + 1;
                        if (finish_lay2_k0) begin
                            finish_lay2_k0 <= 0;
                        end else begin
                            finish_lay2_k0 <= 1;
                        end
                        if (caddr_wr >= 32 * 32 * 2) begin
                            state <= Finish;
                        end else begin
                            state <= WRITE_L2_WAIT; 
                        end
                    end

                    WRITE_L2_WAIT: begin
                        cwr <= 1'b0;
                        state <= SET_READ_L2;
                    end

                    Finish: begin
                    end
                endcase 
            end
        end
    end
endmodule