// Asynchronous assertion, release only on the receiving clock.
module reset_sync(input clk,input async_reset,output reset);
 (* async_reg = "true", preserve = "true" *) reg [1:0] pipe;
 always @(posedge clk or posedge async_reset)
  if(async_reset)pipe<=2'b11;else pipe<={pipe[0],1'b0};
 assign reset=pipe[1];
endmodule
