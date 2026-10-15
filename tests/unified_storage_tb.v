`timescale 1ns/1ps
module unified_storage_tb;
parameter ENABLE_SCALE=0;
reg clk=0;always #5 clk=~clk;reg rst=1,start=0,valid=0,done=0;reg[7:0]data=0;
reg[31:0]last=10000;wire ready,scan_done,found,req,write_req,pixel_we,load_done;wire[31:0] addr,found_addr;wire[3:0]total;wire[3:0]state,err;wire[23:0]pixel;
reg[7:0]header[0:53];reg[31:0]positions[0:7];reg[3:0]target=6;integer mode=0,count=0,k,a,n,h,requests=0,idle_cycles=0;
bmp_read #(.ENABLE_SCALE(ENABLE_SCALE)) dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(start),.scan_start_sector(32'd0),.scan_max_sector(last),.scan_target_count(target),.scan_done(scan_done),.scan_found_valid(found),.scan_found_sector(found_addr),.scan_found_total(total),.load_start(1'b0),.load_abort(1'b0),.load_sector(32'd0),.sd_init_done(1'b1),.state_code(state),.bmp_width(16'd640),.bmp_height(16'd480),.write_req(write_req),.write_req_ack(1'b0),.sd_sec_read(req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(done),.bmp_data_wr_en(pixel_we),.bmp_data(pixel),.sd_sec_read_error(1'b0),.load_done(load_done),.error_code(err));
initial forever begin
 wait(req&&!rst);a=addr;requests=requests+1;
 if((requests%512)==0)begin $display("PROGRESS scan mode=%0d requests=%0d sector=%0d time=%0t",mode,requests,a,$time);$fflush();end
 h=-1;for(n=0;n<8;n=n+1)if(a==positions[n])h=n;
 for(k=0;k<512;k=k+1)begin
  @(negedge clk);valid=1;data=0;
  if(mode!=2&&h>=0&&k<54)data=header[k];
  
 end
 @(negedge clk);valid=0;done=1;@(negedge clk);done=0;
 wait(!req||rst);repeat(3)@(negedge clk);
end
always @(posedge clk)begin
 if(rst||ready||valid||done)idle_cycles=0;else idle_cycles=idle_cycles+1;
 if(idle_cycles>10000)$fatal(1,"scan no sector progress 100us state=%0d addr=%0d",state,addr);
end
always @(posedge clk)if(found)begin
 if(found_addr!==positions[count])$fatal(1,"scan order/address wrong");count=count+1;
end
task run_case;input integer m;input integer expected;
 begin
 mode=m;count=0;rst=1;$display("PROGRESS scan case=%0d begin time=%0t",m,$time);$fflush();repeat(4)@(negedge clk);rst=0;repeat(3)@(negedge clk);
 target=8;last=(m==0)?5*1801:7*1801;start=1;@(negedge clk);start=0;wait(!ready);wait(ready);repeat(3)@(negedge clk);
 if(!scan_done||count!=expected||total!=expected||err!=0||pixel_we||write_req)$fatal(1,"scan case %0d failed count=%0d",m,count);
 $display("PASS discovery mode=%0d count=%0d",m,count);$fflush();
 end
endtask
initial begin
 for(n=0;n<54;n=n+1)header[n]=0;
 header[0]="B";header[1]="M";{header[5],header[4],header[3],header[2]}=921654;
 header[10]=54;header[14]=40;{header[21],header[20],header[19],header[18]}=640;
 {header[25],header[24],header[23],header[22]}=480;header[26]=1;header[28]=24;
 for(n=0;n<8;n=n+1)positions[n]=n*1801;
 run_case(0,6);run_case(1,8);
 $display("TEST_PASS UNIFIED_STORAGE six scan-end and eight capacity discovery; requests=%0d",requests);$finish;
end
initial begin #100000000;$fatal(1,"scan timeout");end
endmodule
