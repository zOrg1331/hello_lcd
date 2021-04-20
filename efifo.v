`default_nettype none

// http://www.electrosofts.com/verilog/fifo.html

module efifo(
             input                    clk,
             input                    rst,
             input [7:0]              buf_in, // data input to be pushed to buffer
             output reg [7:0]         buf_out, // port to output the data
             input                    wr_en,
             input                    rd_en,
             output reg               buf_empty,
             output reg               buf_full,
             output reg [BUF_WIDTH:0] fifo_counter // number of data pushed in to buffer
             );

   // BUF_SIZE = 16 -> BUF_WIDTH = 4, no. of bits to be used in pointer
   parameter BUF_WIDTH = 3;
   localparam BUF_SIZE = (1<<BUF_WIDTH);

   // pointer to read and write addresses
   reg [BUF_WIDTH-1:0]                rd_ptr, wr_ptr;
   reg [7:0]                          buf_mem[BUF_SIZE-1:0];

   always @(fifo_counter) begin
      buf_empty = (fifo_counter == 0);
      buf_full = (fifo_counter == BUF_SIZE);
   end

   always @(posedge clk or posedge rst) begin
      if (rst)
        fifo_counter <= 0;
      else if ((!buf_full && wr_en) && (!buf_empty && rd_en))
        fifo_counter <= fifo_counter;
      else if (!buf_full && wr_en)
        fifo_counter <= fifo_counter + 1;
      else if (!buf_empty && rd_en)
        fifo_counter <= fifo_counter - 1;
      else
        fifo_counter <= fifo_counter;
   end

   always @(posedge clk or posedge rst) begin
      if (rst)
        buf_out <= 0;
      else begin
         if (rd_en && !buf_empty)
           buf_out <= buf_mem[rd_ptr];
         else
           buf_out <= buf_out;
      end
   end

   always @(posedge clk) begin
      if (wr_en && !buf_full)
        buf_mem[wr_ptr] <= buf_in;
      else
        buf_mem[wr_ptr] <= buf_mem[wr_ptr];
   end

   always @(posedge clk or posedge rst) begin
      if (rst) begin
         wr_ptr <= 0;
         rd_ptr <= 0;
      end else begin
         if (!buf_full && wr_en)
           wr_ptr <= wr_ptr + 1;
         else
           wr_ptr <= wr_ptr;

         if (!buf_empty && rd_en)
           rd_ptr <= rd_ptr + 1;
         else
           rd_ptr <= rd_ptr;
      end
   end
endmodule
