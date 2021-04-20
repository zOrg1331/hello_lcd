# Hello World on LCD HD44780

This is a simple (sarcasm) "Hello world!" project written in Verilog.

The project prints `Hello\nworld!` string to LCD module compatible with HD44780
specification.

In order to achieve this goal the following modules were developed (copy-pasted
from various resources):

- `lcd_hd44780.v` LCD driver, heavily rewritten sample provided in
  http://robotics.hobbizine.com/fpgalcd.html
- `efifo.v` FIFO implementation which allows simultaneous reads and writes,
  copy-pasted with cosmetic changes from
  http://www.electrosofts.com/verilog/fifo.html
- `lcd_printer.v` a custom module which prints the provided input data on LCD
  using FIFO as a buffer
- `debouncer.v` a module copy-pasted from
  https://zipcpu.com/tutorial/ex-07-bouncing.tgz which implements hardware
  button/switches debounce
- `hello_lcd.v` prints a string with help of `lcd_printer` when a switch toggled

*NOTE*: there is no top file as it will be hardware-depended. In my case
`hello_lcd` instantiation was like:

```
   hello_lcd top(
                 .user_dipsw(user_dipsw),
                 .clk(clkin_50_top),
                 .lcd_d_c(lcd_d_cn),
                 .lcd_cs(lcd_csn),
                 .lcd_data(lcd_data),
                 .lcd_we(lcd_wen)
                 );
```

## Purpose

This has been written just to play with Verilog while implementing some
real-world application. That is why there are several components which can be
considered as excessive: LCD module (instead of UART), FIFO (instead of direct
write), debouncer.

In practice, FIFO is helpful as printing a string (i.e. for logging purposes) is
fast operation while pushing it to real device is quite slow.

## Simulation

The project was simulated using Verilator before programming a device. The
simulation approach was taken from a great course which inspired me:
https://zipcpu.com/tutorial/

For simulation purposes one can find the following:

- `hello_lcd_tb.cpp` a program which drives the design properly and saves trace
  which can later be opened with `gtkwave`
- `Makefile` compiles the whole project and runs the testbench
