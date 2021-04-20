
#include <verilatedos.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <signal.h>
#include "verilated.h"

#include "Vhello_lcd.h"
#include "testb.h"

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  TESTB<Vhello_lcd> *tb = new TESTB<Vhello_lcd>;

  tb->opentrace("/tmp/hello_lcd.vcd");

  for (unsigned clocks = 0; clocks < (2 << 20); clocks++) {
    tb->tick();
    if (clocks > 5) {
      // do LCD initialization
      tb->m_core->user_dipsw = 0x1;
    }
    if (tb->m_core->hello_lcd__DOT__printer__DOT__initialized) {
      tb->tick();
      tb->tick();
      // do print
      tb->m_core->user_dipsw = 0x3;
    }
    // we are waiting for 12 characters to be printed
    if (tb->m_core->hello_lcd__DOT__i >= 12) {
      if (tb->m_core->hello_lcd__DOT__printer__DOT__fifo_empty &&
          !tb->m_core->hello_lcd__DOT__printer__DOT__fifo_rd_char &&
          !tb->m_core->hello_lcd__DOT__printer__DOT__fifo_prev_rd &&
          !tb->m_core->hello_lcd__DOT__printer__DOT__lcd_busy) {
              tb->tick();
              break;
      }
    }
  }

  printf("\n\nSimulation complete\n");
}
