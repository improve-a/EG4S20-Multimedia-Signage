`timescale 1ns/1ps
`include "rtl/include/global_def.v"
module clock_config_tb;
 initial begin
  if(`SDR_CLK_PERIOD != 25)$fatal(1,"SDRAM period=%0d",`SDR_CLK_PERIOD);
  if(`SELF_REFRESH_INTERVAL != 600)$fatal(1,"refresh cycles=%0d",`SELF_REFRESH_INTERVAL);
  $display("TEST_PASS clock_config period_ns=%0d refresh_cycles=%0d",`SDR_CLK_PERIOD,`SELF_REFRESH_INTERVAL);$finish;
 end
endmodule
