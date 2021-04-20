`default_nettype  none

// https://zipcpu.com/tutorial/ex-07-bouncing.tgz

module debouncer(
                 input      i_clk,
                 input      i_btn,
                 output reg o_debounced
                 );
   parameter TIME_PERIOD = 75000;

   reg                      r_btn, r_aux;
   reg [15:0]               timer;

   // Our 2FF synchronizer
   initial { r_btn, r_aux } = 2'b00;
   always @(posedge i_clk)
     { r_btn, r_aux } <= { r_aux, i_btn };

   // The count-down timer
   initial timer = 0;
   always @(posedge i_clk)
     if (timer != 0)
       timer <= timer - 1;
     else if (r_btn != o_debounced)
       timer <= TIME_PERIOD[15:0] - 1;

   // Finally, set our output value
   initial o_debounced = 0;
   always @(posedge i_clk)
     if (timer == 0)
       o_debounced <= r_btn;
endmodule // debouncer
