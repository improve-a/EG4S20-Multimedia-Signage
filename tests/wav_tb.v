`timescale 1ns/1ps
module wav_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0,byte_valid=0;reg [7:0] byte_data;
wire recognized,header_valid,done,stereo,pcm_valid;wire[3:0] error_code;
wire[31:0] data_offset,data_length,file_length;wire[15:0] left,right;
reg[7:0] memory[0:4095];integer count=0,mode=0,i;reg contiguous=0;
wav_stream_parser dut(clk,rst,start,byte_data,byte_valid,recognized,header_valid,done,error_code,stereo,data_offset,data_length,file_length,pcm_valid,left,right);
always @(negedge clk)if(pcm_valid)begin
 if(mode==2||mode==3)$fatal(1,"Invalid header emitted PCM");
 if($signed(left)!=-30000+count*97)$fatal(1,"left order idx %0d value %0d",count,$signed(left));
 if($signed(right)!=(mode==0?25000-count*83:-30000+count*97))$fatal(1,"right idx %0d value %0d",count,$signed(right));
 count=count+1;
end
task send;
 input integer n;integer j;
 begin
  for(j=0;j<n;j=j+1)begin
   @(negedge clk);byte_valid=1;byte_data=memory[j];
   if(!contiguous)begin @(negedge clk);byte_valid=0;end
  end
  @(negedge clk);byte_valid=0;repeat(4)@(negedge clk);
 end
endtask
task reset_parser;
 begin @(negedge clk);start=1;@(negedge clk);start=0;count=0;end
endtask
initial begin
 repeat(3)@(negedge clk);rst=0;
 $readmemh("tests/audio_stereo.hex",memory,0,1765);send(1766);
 if(!recognized||!header_valid||!done||error_code||!stereo||count!=300||data_offset!=566||data_length!=1200)$fatal(1,"stereo header/count offset=%0d count=%0d err=%0d",data_offset,count,error_code);
 // Continuous acceptance must preserve odd-chunk padding, offsets and PCM.
 contiguous=1;reset_parser;send(1766);
 if(!done||error_code||count!=300||data_offset!=566)$fatal(1,"continuous stereo mismatch");
 mode=1;reset_parser;$readmemh("tests/audio_mono.hex",memory,0,243);send(244);
 if(!done||error_code||stereo||count!=100)$fatal(1,"mono mismatch");
 // Exact-fit data boundary is accepted with gaps and contiguous bytes.
 contiguous=0;reset_parser;send(244);
 if(!done||error_code||count!=100||data_offset!=44)$fatal(1,"gapped exact fit mismatch");
 // One byte short RIFF boundary rejects data before PCM, in both schedules.
 mode=3;memory[4]=235;memory[5]=0;memory[6]=0;memory[7]=0;
 reset_parser;send(244);
 if(error_code!=2||header_valid||count)$fatal(1,"gapped one byte overflow accepted");
 contiguous=1;reset_parser;send(244);
 if(error_code!=2||header_valid||count)$fatal(1,"contiguous one byte overflow accepted");
 // A zero-length unknown chunk consumes eight bytes; the following payload
 // begins outside RIFF. The unsigned subtraction must never hide this case.
 $readmemh("tests/audio_mono.hex",memory,0,243);
 for(i=43;i>=36;i=i-1)memory[i+8]=memory[i];
 memory[36]=8'h4a;memory[37]=8'h55;memory[38]=8'h4e;memory[39]=8'h4b;
 memory[40]=0;memory[41]=0;memory[42]=0;memory[43]=0;
 memory[4]=36;memory[5]=0;memory[6]=0;memory[7]=0;
 reset_parser;send(52);
 if(error_code!=2||header_valid||count)$fatal(1,"outside payload start accepted");
 // Restart and reset after cached rejection cannot leak stale bounds.
 mode=1;reset_parser;$readmemh("tests/audio_mono.hex",memory,0,243);send(244);
 if(!done||error_code||count!=100)$fatal(1,"start retained stale bounds");
 @(negedge clk);rst=1;@(negedge clk);rst=0;count=0;send(244);
 if(!done||error_code||count!=100)$fatal(1,"reset retained stale bounds");
 mode=2;reset_parser;$readmemh("tests/audio_bad_rate.hex",memory,0,1243);send(1244);
 if(error_code!=3||header_valid||count!=0)$fatal(1,"unsupported rate accepted");
 mode=3;reset_parser;$readmemh("tests/audio_bad_size.hex",memory,0,1243);send(1244);
 if(error_code!=2||header_valid||count!=0)$fatal(1,"chunk outside RIFF accepted");
 $display("TEST_PASS WAV parser: stereo/mono signed order, 513B JUNK odd pad, continuous/gapped acceptance, exact fit, one-byte overflow, outside start, stale-cache start/reset, invalid rate and RIFF bounds");$finish;
end
endmodule
