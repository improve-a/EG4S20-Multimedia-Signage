`timescale 1ns/1ps
// Full delivery-file byte stream through the unchanged production parser.
// This is accelerated parser validation, not48kHz real-time playback/system SD.
module no_bot_wav_full_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,start=0,byte_valid=0;reg[7:0]byte_data=0;
 wire recognized,header_valid,done,stereo,pcm_valid;
 wire[3:0]error_code;wire[31:0]data_offset,data_length,file_length;
 wire[15:0]pcm_left,pcm_right;
 integer wav_file,expected_file,actual_file;
 integer current_byte,expected_low,expected_high,expected_sample;
 integer input_bytes=0,actual_samples=0,expected_samples=3840000;
 integer expected_bytes=7680044,expected_offset=44,expected_data_bytes=7680000;
 integer eof_samples=-1,eof_input=-1,done_edges=0,clock_cycles=0;
 reg prev_done=0,completed_input=0;
 wav_stream_parser dut(clk,rst,start,byte_data,byte_valid,recognized,header_valid,done,error_code,
                       stereo,data_offset,data_length,file_length,pcm_valid,pcm_left,pcm_right);
 always @(negedge clk) begin
  clock_cycles=clock_cycles+1;
  if(!rst&&!start)begin
   if(error_code!=0)$fatal(1,"parser error%0d bytes%0d samples%0d",error_code,input_bytes,actual_samples);
   if(pcm_valid)begin
    if(actual_samples>=expected_samples)$fatal(1,"extra PCM after declared data end");
    expected_low=$fgetc(expected_file);expected_high=$fgetc(expected_file);
    if(expected_low<0||expected_high<0)$fatal(1,"expected PCM ended before actual sample%0d",actual_samples);
    expected_sample=expected_low|(expected_high<<8);
    if(pcm_left!==expected_sample[15:0]||pcm_right!==expected_sample[15:0])
     $fatal(1,"PCM mismatch index%0d expected%04x L%04x R%04x",actual_samples,expected_sample,pcm_left,pcm_right);
    $fwrite(actual_file,"%c%c%c%c",pcm_left[7:0],pcm_left[15:8],pcm_right[7:0],pcm_right[15:8]);
    actual_samples=actual_samples+1;
    if(actual_samples%480000==0)$display("PROGRESS samples=%0d of%0d input_bytes=%0d",actual_samples,expected_samples,input_bytes);
   end
   if(done&&!prev_done)begin
    done_edges=done_edges+1;eof_samples=actual_samples;eof_input=input_bytes;
    if(actual_samples!=expected_samples)$fatal(1,"premature EOF samples%0d expected%0d",actual_samples,expected_samples);
   end
   prev_done=done;
  end
 end
 initial begin
  if($value$plusargs("SAMPLES=%d",expected_samples))begin end
  if($value$plusargs("FILE_BYTES=%d",expected_bytes))begin end
  if($value$plusargs("DATA_OFFSET=%d",expected_offset))begin end
  if($value$plusargs("DATA_BYTES=%d",expected_data_bytes))begin end
  wav_file=$fopen("delivery.wav","rb");expected_file=$fopen("expected_pcm.bin","rb");actual_file=$fopen("parser_pcm_lr.bin","wb");
  if(!wav_file||!expected_file||!actual_file)$fatal(1,"could not open full-file fixtures/output");
  repeat(4)@(negedge clk);rst=0;start=1;
  @(negedge clk);start=0;
  current_byte=$fgetc(wav_file);
  while(current_byte>=0)begin
   byte_data=current_byte[7:0];byte_valid=1;input_bytes=input_bytes+1;
   @(negedge clk);
   current_byte=$fgetc(wav_file);
  end
  byte_valid=0;completed_input=1;
  repeat(4)@(negedge clk);
  if(input_bytes!=expected_bytes)$fatal(1,"full source length mismatch%0d",input_bytes);
  if(!recognized||!header_valid||!done||stereo||error_code!=0)$fatal(1,"header/done/mono status bad");
  if(data_offset!=expected_offset||data_length!=expected_data_bytes||file_length!=expected_bytes)
   $fatal(1,"RIFF extent offset%0d data%0d file%0d",data_offset,data_length,file_length);
  if(actual_samples!=expected_samples||eof_samples!=expected_samples||done_edges!=1)
   $fatal(1,"EOF/sample count samples%0d eof%0d edges%0d",actual_samples,eof_samples,done_edges);
  if($fgetc(expected_file)!=-1)$fatal(1,"expected PCM has unconsumed tail");
  // Extra transport padding is not part of the source file. STOP must emit no more samples.
  repeat(64)begin byte_data=8'ha5;byte_valid=1;@(negedge clk);end
  byte_valid=0;repeat(4)@(negedge clk);
  if(actual_samples!=expected_samples||!done||done_edges!=1)$fatal(1,"STOP consumed padding or lost EOF");
  $fclose(wav_file);$fclose(expected_file);$fclose(actual_file);
  $display("TEST_PASS full production WAV parser: file_bytes=%0d data_offset=%0d data_bytes=%0d samples=%0d mono_LR_exact=1 EOF_edges=%0d EOF_input_position=%0d clocks=%0d padding_ignored=64",input_bytes,data_offset,data_length,actual_samples,done_edges,eof_input,clock_cycles);
  $finish;
 end
 initial begin #100000000;$fatal(1,"full parser simulation timeout bytes%0d samples%0d",input_bytes,actual_samples);end
endmodule
