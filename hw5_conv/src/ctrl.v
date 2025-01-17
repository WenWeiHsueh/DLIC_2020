`include "def.v"

module ctrl (
  input                               clk,
  input                               reset,
  input                               start,
  output reg                          dp_cnt_rst,
  input             [`INT_FLAG_W-1:0] fb_flags,
  output reg        [`CMD_FLAG_W-1:0] cmd_flags,
  output reg         [`GLB_CNT_W-1:0] glb_idx_x,
  output reg         [`GLB_CNT_W-1:0] glb_idx_y
);

  reg                [`STATE_W-1:0] curr_state, next_state;
  
  // State Register (S)
  always @(posedge clk) begin
     if(reset)
       curr_state <= {`S_ZVEC | {{(`STATE_W-1){1'b0}}, 1'b1}};
     else
       curr_state <= next_state;
  end // State Register

  // Wait for interrupt signal
  wire                 wait_done = start;
  wire                 read_done = fb_flags[`INT_READ];
  wire                 read_w_done = fb_flags[`INT_READ_W];
  wire                  opt_done = fb_flags[`INT_OPT];
  wire            write_all_done = fb_flags[`INT_WRITE] & 
                                   (glb_idx_x == (`IMG_SIZE-3)) & 
                                   (glb_idx_y == (`IMG_SIZE-3));
  wire           write_nyet_done = fb_flags[`INT_WRITE];

  // Next State Logic (C)
  always @(*) begin
     next_state = `S_ZVEC;

     case (1'b1)

       // WAIT state
       curr_state[`S_WAIT]: begin
          if(wait_done)
            next_state[`S_READ_W] = 1'b1;
          else
            next_state[`S_WAIT] = 1'b1;
       end

       // READ_W state
       curr_state[`S_READ_W]: begin
          if(read_w_done)
             next_state[`S_READ] = 1'b1;
          else
            next_state[`S_READ_W] = 1'b1;
       end

       // READ state
       curr_state[`S_READ]: begin
          if(read_done)
             next_state[`S_OPT] = 1'b1;
          else
            next_state[`S_READ] = 1'b1;
       end

       // OPT state
       curr_state[`S_OPT]: begin
          if(opt_done)
            next_state[`S_WRITE] = 1'b1;
          else
            next_state[`S_OPT] = 1'b1;
       end

       // WRITE state
       curr_state[`S_WRITE]: begin
          if(write_all_done)
            next_state[`S_END] = 1'b1;
          else if(write_nyet_done)
            next_state[`S_READ] = 1'b1;
          else
            next_state[`S_WRITE] = 1'b1;
       end

       // End state
       curr_state[`S_END]: begin
          next_state[`S_END] = 1'b1;
       end

       // default
       default: begin
          next_state[`S_READ] = 1'b1;
       end
     endcase

  end // Next State Logic (C)

  // Output Logic (C)
  always @(*) begin
    cmd_flags = {`CMD_FLAG_W{1'b0}}; 
    dp_cnt_rst = 1'b0;

    case (1'b1)

      // WAIT state
      curr_state[`S_WAIT]: begin
        cmd_flags[`CMD_WAIT] = 1'b1;
        dp_cnt_rst = 1;
      end

      // READ_W state
      curr_state[`S_READ_W]: begin
        cmd_flags[`CMD_READ_W] = 1'b1;
        if(read_w_done) begin
          dp_cnt_rst = 1;
        end
      end

      // READ state
      curr_state[`S_READ]: begin
        cmd_flags[`CMD_READ] = 1'b1;
        if(read_done) begin
          dp_cnt_rst = 1;
        end
      end

      // OPT state
      curr_state[`S_OPT]: begin
        cmd_flags[`CMD_OPT] = 1'b1;
        if(opt_done) begin
          dp_cnt_rst = 1;
        end
      end

      // WRITE state
      curr_state[`S_WRITE]: begin
        cmd_flags[`CMD_WRITE] = 1'b1;
        dp_cnt_rst = 1;
      end

      // End state
      curr_state[`S_END]: begin
        cmd_flags[`CMD_END] = 1'b1;
      end
      
      //default
      default: begin
        cmd_flags[`CMD_READ] = 1'b1;
      end
    endcase

  end // Next State Logic (C)

  always @(posedge clk) begin
    if(reset) begin
      glb_idx_x <= 0;
      glb_idx_y <= 0;
    end else if(fb_flags[`INT_WRITE]) begin
      if(glb_idx_x == (`IMG_SIZE-1)) begin
        glb_idx_x <= 0;
        glb_idx_y <= glb_idx_y + 1;
      end else begin
        glb_idx_x <= glb_idx_x + 1;
        glb_idx_y <= glb_idx_y;
      end
    end
  end

endmodule
