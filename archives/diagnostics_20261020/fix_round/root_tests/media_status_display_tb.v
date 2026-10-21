`timescale 1ns/1ps
module media_status_display_tb;
 reg clk=0,rst=1;always #10 clk=~clk;
 reg [27:0] flags=0;
 reg video_rst=0,sys_lock=1,video_lock=1;
 wire [23:0] digits;wire [2:0] page_number;
 hdmi_probe_display #(.PAGE_CYCLES(100)) dut(clk,rst,flags,video_rst,sys_lock,video_lock,digits,page_number);
 integer checks=0,p;
 task wait_page;
  input [2:0] target;integer n;
  begin
   n=0;
   while(page_number!==target && n<600)begin @(negedge clk);n=n+1;end
   if(n>=600)$fatal(1,"page timeout");
   repeat(4)@(negedge clk);
  end
 endtask
 task expect_digits;
  input [23:0] expected;
  begin
   if(digits!==expected)$fatal(1,"display mismatch page=%d got=%h expected=%h",page_number,digits,expected);
   checks=checks+1;
  end
 endtask
 initial begin
  // B-like fault signature: lock stable, media D, no publication, SD/SDRAM ready,
  // WAV IDLE and tone still selected, active page1/buffer0.
  flags[4:0]=5'b00111;
  flags[8:5]=4'hd;flags[9]=0;flags[10]=0;flags[11]=1;
  flags[15:12]=1;flags[16]=0;flags[24]=1;
  repeat(4)@(negedge clk);rst=0;
  for(p=1;p<=5;p=p+1)begin
   wait_page(p);
   case(p)
    1:expect_digits(24'h111100);
    2:expect_digits(24'h2d0001);
    3:expect_digits(24'h310000);
    4:expect_digits(24'h410000);
    5:expect_digits(24'h510110);
   endcase
  end
  // Published image + latched storage fault and post-selection WAV errors.
  @(negedge clk);flags[8:5]=4'ha;flags[9]=1;flags[10]=1;flags[25]=1;
  flags[15:12]=4'he;flags[16]=1;flags[17]=1;flags[18]=1;flags[19]=1;
  flags[22:20]=3'd5;flags[23]=1;
  wait_page(2);expect_digits(24'h2a1111);
  wait_page(3);expect_digits(24'h3e1111);
  wait_page(4);expect_digits(24'h461000);
  wait_page(5);expect_digits(24'h510110);
  // Same displayed state number must distinguish scanner from media sequencer.
  @(negedge clk);flags[8:5]=4'd2;flags[9]=0;flags[10]=0;flags[25]=0;
  wait_page(2);expect_digits(24'h220001);
  @(negedge clk);flags[25]=1;repeat(4)@(negedge clk);
  expect_digits(24'h221001);
  $display("MEDIA_STATUS_DISPLAY_PASS checks=%0d",checks);$finish;
 end
 initial begin #200000;$fatal(1,"test timeout");end
endmodule
