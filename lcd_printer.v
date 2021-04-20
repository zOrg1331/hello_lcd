/* verilator lint_off UNUSED */

`default_nettype none

module lcd_printer(
                   input            clk,
                   output           lcd_we, // LCD hardware pins
                   output           lcd_d_c,
                   output           lcd_cs,
                   inout wire [7:0] lcd_data,
                   input            lcd_init, // set high to init LCD
                   input wire [7:0] char, // what symbol to output
                   input wire       print, // set high to print 'char'
                   output wire      busy // high means inability to print
                   );

   // LCD wires
   reg [7:0]                        lcd_data_in;
   reg                              lcd_do_cmd;
   reg                              lcd_do_write;
   wire                             lcd_busy;
   wire                             initialized;

   // FIFO wires
   reg                              fifo_write_char;
   reg                              fifo_rd_char;
   reg [7:0]                        fifo_char_in;
   wire [7:0]                       fifo_char_out;
   wire                             fifo_rst, fifo_full, fifo_empty;
   wire [8:0]                       fifo_fill;

   // helper to store the previous state of FIFO read command
   reg                              fifo_prev_rd;

   lcd_hd44780
`ifdef  VERILATOR
     #(.CLK_FREQ(500000))
`else
   #(.CLK_FREQ(50000000))
`endif
   lcd(
       .clk(clk),
       .RS(lcd_d_c),
       .E(lcd_cs),
       .DB(lcd_data),
       .data(lcd_data_in),
       .do_init(lcd_init),
       .wr_cmd(lcd_do_cmd),
       .wr_char(lcd_do_write),
       .busy(lcd_busy),
       .initialized(initialized)
       );

   efifo #(.BUF_WIDTH(8)) fifo(
                               .clk(clk),
                               .rst(fifo_rst),
                               .buf_in(fifo_char_in),
                               .buf_out(fifo_char_out),
                               .wr_en(fifo_write_char),
	  	                         .rd_en(fifo_rd_char),
                               .buf_empty(fifo_empty),
                               .buf_full(fifo_full),
                               .fifo_counter(fifo_fill)
                               );

   // tie LCD write enable signal to ground
   assign lcd_we = 0;

   // we are busy only if FIFO is full
   assign busy = fifo_full;

   assign fifo_rst = 1'b0;

   initial fifo_prev_rd = 1'b0;

   // input data just goes to FIFO
   always @(posedge clk) begin
      fifo_write_char <= print;
      fifo_char_in <= char;
   end

   always @(posedge clk) begin
      // we need the previous state of FIFO read command
      // as FIFO returns a byte on 1 tick after read command
      if (!fifo_empty && !lcd_busy) begin
         fifo_rd_char <= 1'b1;
         fifo_prev_rd <= 1'b0;
      end
      if (!fifo_empty && fifo_rd_char) begin
         fifo_rd_char <= 1'b0;
         fifo_prev_rd <= 1'b1;
      end

      // this handles the last byte in FIFO
      if (fifo_empty && fifo_prev_rd && !lcd_busy) begin
         fifo_rd_char <= 1'b1;
         fifo_prev_rd <= 1'b0;
      end

      // this stops interactions
      if (fifo_empty && !fifo_prev_rd && fifo_rd_char && !lcd_busy) begin
         fifo_rd_char <= 1'b0;
         fifo_prev_rd <= 1'b0;
      end

      // in this state FIFO output buffer will have a valid byte
      if (fifo_prev_rd && !lcd_busy) begin
         if (fifo_char_out == 8'h0A) begin
            // if \n is in the string, send newline command
            lcd_do_cmd <= 1'b1;
            lcd_data_in <= 8'hC0;
         end else if ((fifo_char_out >= 8'h20) &&
                      (fifo_char_out <= 8'h7E)) begin
            // for normal character, send it
            lcd_do_write <= 1'b1;
            lcd_data_in <= fifo_char_out;
         end else begin
            // else, send space
            lcd_data_in <= 8'h20;
            lcd_do_write <= 1'b1;
         end
      end

      // do not forget to set commands to low
      if (lcd_busy && (lcd_do_write || lcd_do_cmd)) begin
         lcd_do_write <= 1'b0;
         lcd_do_cmd <= 1'b0;
      end
   end
endmodule
