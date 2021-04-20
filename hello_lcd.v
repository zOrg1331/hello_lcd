/* verilator lint_off UNUSED */

`default_nettype none

module hello_lcd(
                 input [3:0]  user_dipsw,
                 input        clk,
                 output       lcd_d_c,
                 output       lcd_cs,
                 inout [7:0]  lcd_data,
                 output       lcd_we
               );

   wire                       lcd_init;

   reg                        print_char;
   reg [7:0]                  char2print;
   wire                       printer_busy;

   wire                       print_str;
   localparam integer         STR_LEN = 12;
   integer                    i;
   reg [(STR_LEN*8 - 1):0]    str = "Hello\nworld!";

   // switches should go via debouncers
   // 75000 == 1.5ms when clock is 50 MHz
   debouncer #(.TIME_PERIOD(75000)) init_button(
                                                .i_clk(clk),
                                                .i_btn(user_dipsw[0]),
                                                .o_debounced(lcd_init)
                                                );
   debouncer #(.TIME_PERIOD(75000)) print_button(
                                                .i_clk(clk),
                                                .i_btn(user_dipsw[1]),
                                                .o_debounced(print_str)
                                                );

   lcd_printer printer(
                       .clk(clk),
                       .lcd_we(lcd_we),
                       .lcd_d_c(lcd_d_c),
                       .lcd_cs(lcd_cs),
                       .lcd_data(lcd_data),
                       .lcd_init(lcd_init),
                       .char(char2print),
                       .print(print_char),
                       .busy(printer_busy)
                       );

   initial i = 0;

   always @(posedge clk) begin
      // only act when asked to
      if (print_str == 1'b1) begin
         // by default we do not issue any command
         print_char <= 1'b0;

         // if printer is not busy and we did not print all
         // we wanted to - command to print
         if (!printer_busy) begin
            if (i < STR_LEN) begin
               print_char <= 1'b1;
               // we count backwards as we initialized array as a string
               char2print <= str[8*(STR_LEN-i-1) +: 8];
            end
         end

         // when printer is busy and/or we commanded to print
         // release the command as we do not want to print continously
         // IMPORTANT: this is also the right moment to increment
         // character address as the module is busy with processing the
         // previous one
         if (printer_busy || print_char) begin
            if (i < STR_LEN) begin
               print_char <= 1'b0;
               i <= i + 1;
            end
         end
      end
   end
endmodule
