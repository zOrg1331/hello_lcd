/* verilator lint_off REALCVT */
`default_nettype none

// this is based on http://robotics.hobbizine.com/fpgalcd.html

module lcd_hd44780(
                   input            clk,
                   output reg       RS,
                   output reg       E,
                   output reg [7:0] DB,
                   input [7:0]      data, // data to write (character address or command)
                   input            do_init, // perform initialization
                   input            wr_cmd, // send command
                   input            wr_char, // write character
                   output reg       initialized, // 1 - LCD initialized
                   output reg       busy // 1 - is not ready to accept data
                   );

   parameter CLK_FREQ = 100000000;

   localparam integer               D_50ns  = 0.000000050 * CLK_FREQ;
   localparam integer               D_250ns = 0.000000250 * CLK_FREQ;

   localparam integer               D_40us  = 0.000040000 * CLK_FREQ;
   localparam integer               D_60us  = 0.000060000 * CLK_FREQ;
   localparam integer               D_200us = 0.000200000 * CLK_FREQ;

   localparam integer               D_2ms   = 0.002000000 * CLK_FREQ;
   localparam integer               D_5ms   = 0.005000000 * CLK_FREQ;
   localparam integer               D_100ms = 0.100000000 * CLK_FREQ;

   localparam STATE_UNDEFINED             = 8'b00000000;
   localparam STATE_INIT_START            = 8'b00000001;
   localparam STATE_EN_TRIGGERED_1        = 8'b00000010;
   localparam STATE_EN_TRIGGERED_2        = 8'b00000011;
   localparam STATE_EN_TRIGGERED_3        = 8'b00000100;
   localparam STATE_EN_TRIGGERED_4        = 8'b00000101;
   localparam STATE_EN_TRIGGERED_5        = 8'b00000110;
   localparam STATE_EN_TRIGGERED_6        = 8'b00000111;
   localparam STATE_FUNCTION_SET_LOADING  = 8'b00001000;
   localparam STATE_CONFIGURATION_LOADING = 8'b00001001;
   localparam STATE_DISP_OFF_LOADING      = 8'b00001010;
   localparam STATE_CLEAR_LOADING         = 8'b00001011;
   localparam STATE_ENTRY_MODE_LOADING    = 8'b00001100;
   localparam STATE_DISP_ON_LOADING       = 8'b00001101;
   localparam STATE_DISP_ON_ENABLED       = 8'b00001110;
   localparam STATE_CMD_WRITTEN           = 8'b00001111;
   localparam STATE_CHAR_WRITTEN          = 8'b00010000;

   localparam ACT_IDLE                  = 8'b00000000;
   localparam ACT_INIT_STARTING         = 8'b00000001;
   localparam ACT_FUNCTION_SET_LOADING  = 8'b00000010;
   localparam ACT_CONFIGURATION_LOADING = 8'b00000011;
   localparam ACT_DISP_OFF_LOADING      = 8'b00000100;
   localparam ACT_CLEAR_LOADING         = 8'b00000101;
   localparam ACT_ENTRY_MODE_LOADING    = 8'b00000110;
   localparam ACT_DISP_ON_LOADING       = 8'b00000111;
   localparam ACT_WRITING_CMD           = 8'b00001000;
   localparam ACT_WRITING_CHAR          = 8'b00001001;
   localparam ACT_READY                 = 8'b00001010;

   reg [7:0]                        cur_action;
   reg [7:0]                        next_state;
   reg [31:0]                       cnt;

   initial begin
      // setting signals to their defaults
      RS = 1'b0;
      E = 1'b0;
      DB = 8'b00000000;

      cur_action = ACT_IDLE;
      next_state = STATE_INIT_START;

      busy = 1'b0;
      initialized = 1'b0;
   end

   always @(posedge clk) begin
      // always increment counter
      cnt <= cnt + 32'h1;

      // STATE00
      // performs initialization at the right moment (100ms after request)
      if ((cur_action == ACT_INIT_STARTING) &&
          (next_state == STATE_INIT_START) &&
          (cnt == D_100ms)
          ) begin
         // pull RS low to indicate instruction
         RS <= 1'b0;
         // set data to Function Set instruction
         DB <= 8'b00110000;
         // enable should be 0
         E <= 1'b0;

         // raise and lower the enable pin three times to enter the
         // Function Set instruction that was loaded to the databus
         cur_action <= ACT_FUNCTION_SET_LOADING;
         next_state <= STATE_EN_TRIGGERED_1;
         cnt <= 32'h0;
      end

      // STATE01, STATE08, STATE11, STATE14, STATE17, STATE_20, STATE24
      if ((next_state == STATE_EN_TRIGGERED_1) &&
          ((cur_action == ACT_FUNCTION_SET_LOADING) ||
           (cur_action == ACT_CONFIGURATION_LOADING) ||
           (cur_action == ACT_DISP_OFF_LOADING) ||
           (cur_action == ACT_CLEAR_LOADING) ||
           (cur_action == ACT_ENTRY_MODE_LOADING) ||
           (cur_action == ACT_DISP_ON_LOADING) ||
           (cur_action == ACT_WRITING_CHAR) ||
           (cur_action == ACT_WRITING_CMD)) &&
          (cnt == D_50ns)) begin
         E <= 1'b1;
         next_state <= STATE_EN_TRIGGERED_2;
         cnt <= 32'h0;
      end

      // STATE02, STATE04, STATE06, STATE09, STATE12, STATE15, STATE18, STATE21, STATE24
      if (((next_state == STATE_EN_TRIGGERED_2) ||
           (next_state == STATE_EN_TRIGGERED_4) ||
           (next_state == STATE_EN_TRIGGERED_6)) &&
          ((cur_action == ACT_FUNCTION_SET_LOADING) ||
           (cur_action == ACT_CONFIGURATION_LOADING) ||
           (cur_action == ACT_DISP_OFF_LOADING) ||
           (cur_action == ACT_CLEAR_LOADING) ||
           (cur_action == ACT_ENTRY_MODE_LOADING) ||
           (cur_action == ACT_DISP_ON_LOADING) ||
           (cur_action == ACT_WRITING_CHAR) ||
           (cur_action == ACT_WRITING_CMD)) &&
          (cnt == D_250ns)) begin
         E <= 1'b0;

         if (next_state == STATE_EN_TRIGGERED_2) begin
            if (cur_action == ACT_FUNCTION_SET_LOADING) begin
               next_state <= STATE_EN_TRIGGERED_3;
            end else if (cur_action == ACT_CONFIGURATION_LOADING) begin
               next_state <= STATE_DISP_OFF_LOADING;
            end else if (cur_action == ACT_DISP_OFF_LOADING) begin
               next_state <= STATE_CLEAR_LOADING;
            end else if (cur_action == ACT_CLEAR_LOADING) begin
               next_state <= STATE_ENTRY_MODE_LOADING;
            end else if (cur_action == ACT_ENTRY_MODE_LOADING) begin
               next_state <= STATE_DISP_ON_LOADING;
            end else if (cur_action == ACT_DISP_ON_LOADING) begin
               next_state <= STATE_DISP_ON_ENABLED;
            end else if (cur_action == ACT_WRITING_CHAR) begin
               next_state <= STATE_CHAR_WRITTEN;
            end else if (cur_action == ACT_WRITING_CMD) begin
               next_state <= STATE_CMD_WRITTEN;
            end
         end else if (next_state == STATE_EN_TRIGGERED_4) begin
            if (cur_action == ACT_FUNCTION_SET_LOADING) begin
               next_state <= STATE_EN_TRIGGERED_5;
            end
         end else if (next_state == STATE_EN_TRIGGERED_6) begin
            if (cur_action == ACT_FUNCTION_SET_LOADING) begin
               next_state <= STATE_CONFIGURATION_LOADING;
            end
         end

         cnt <= 32'h0;
      end

      // STATE03
      if ((next_state == STATE_EN_TRIGGERED_3) &&
          (cur_action == ACT_FUNCTION_SET_LOADING) &&
          (cnt == D_5ms)) begin
         E <= 1'b1;
         next_state <= STATE_EN_TRIGGERED_4;
         cnt <= 32'h0;
      end

      // STATE05
      if ((next_state == STATE_EN_TRIGGERED_5) &&
          (cur_action == ACT_FUNCTION_SET_LOADING) &&
          (cnt == D_200us)) begin
         E <= 1'b1;
         next_state <= STATE_EN_TRIGGERED_6;
         cnt <= 32'h0;
      end

      // STATE07
      if ((next_state == STATE_CONFIGURATION_LOADING) &&
          (cur_action == ACT_FUNCTION_SET_LOADING) &&
          (cnt == D_200us)) begin
         // Configuration: 8-bit, 2 lines, 5x7 font 
         DB <= 8'b00111000;
         cur_action <= ACT_CONFIGURATION_LOADING;
         next_state <= STATE_EN_TRIGGERED_1;
         cnt <= 32'h0;
      end

      // STATE10
      if ((next_state == STATE_DISP_OFF_LOADING) &&
          (cur_action == ACT_CONFIGURATION_LOADING) &&
          (cnt == D_60us)) begin
         // Display Off command
         DB <= 8'b00001000;
         cur_action <= ACT_DISP_OFF_LOADING;
         next_state <= STATE_EN_TRIGGERED_1;
         cnt <= 32'h0;
      end

      // STATE13
      if ((next_state == STATE_CLEAR_LOADING) &&
          (cur_action == ACT_DISP_OFF_LOADING) &&
          (cnt == D_60us)) begin
         // Clear command
         DB <= 8'b00000001;
         cur_action <= ACT_CLEAR_LOADING;
         next_state <= STATE_EN_TRIGGERED_1;
         cnt <= 32'h0;
      end

      // STATE16
      if ((next_state == STATE_ENTRY_MODE_LOADING) &&
          (cur_action == ACT_CLEAR_LOADING) &&
          (cnt == D_5ms)) begin
         // Entry Mode: cursor moves, display stands still
         DB <= 8'b00000110;
         cur_action <= ACT_ENTRY_MODE_LOADING;
         next_state <= STATE_EN_TRIGGERED_1;
         cnt <= 32'h0;
      end

      // STATE19
      if ((next_state == STATE_DISP_ON_LOADING) &&
          (cur_action == ACT_ENTRY_MODE_LOADING) &&
          (cnt == D_60us)) begin
         // Display On
         DB <= 8'b00001100;
         cur_action <= ACT_DISP_ON_LOADING;
         next_state <= STATE_EN_TRIGGERED_1;
         cnt <= 32'h0;
      end

      // STATE22
      if ((next_state == STATE_DISP_ON_ENABLED) &&
          (cur_action == ACT_DISP_ON_LOADING) &&
          (cnt == D_60us)) begin
         // set output ports accordingly
         initialized <= 1'b1;
         busy <= 1'b0;

         cur_action <= ACT_READY;
      end

      // STATE25_1
      if ((next_state == STATE_CHAR_WRITTEN) &&
          (cur_action == ACT_WRITING_CHAR) &&
          (cnt == D_40us)) begin
         // set output ports accordingly
         busy <= 1'b0;

         cur_action <= ACT_READY;
      end

      // STATE25_2
      if ((next_state == STATE_CMD_WRITTEN) &&
          (cur_action == ACT_WRITING_CMD) &&
          (cnt == D_2ms)) begin
         // set output ports accordingly
         busy <= 1'b0;

         cur_action <= ACT_READY;
      end

      // start initialization when requested
      if (do_init && !initialized) begin
         if (cur_action == ACT_IDLE) begin
            busy <= 1'b1;
            cur_action <= ACT_INIT_STARTING;
            next_state <= STATE_INIT_START;
            cnt <= 32'h0;
         end
      end

      // begin to write data when requested
      if ((wr_char || wr_cmd) && !busy && initialized) begin
         if (cur_action == ACT_READY) begin
            // STATE23
            busy <= 1'b1;
            // read the data value input
            DB <= data[7:0];
            if (wr_char) begin
               RS <= 1'b1;
               cur_action <= ACT_WRITING_CHAR;
            end else begin
               RS <= 1'b0;
               cur_action <= ACT_WRITING_CMD;
            end
            next_state <= STATE_EN_TRIGGERED_1;
            cnt <= 32'h0;
         end
      end
   end

endmodule
