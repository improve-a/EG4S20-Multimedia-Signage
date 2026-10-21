from pathlib import Path
p=Path(__file__).with_name('video_transition.v')
s=p.read_text()
s=s.replace('// One registered pixel/sync cycle. The commit request is forwarded only after\n// the old image is fully black. The real display_commit acknowledgement gates\n// opening, so buffer selection and SD ownership remain with display_commit.', '''// One registered pixel/sync cycle, using only the current scanout pixel and a
// constant mask (plus the original one-line slide RAM). In pre-load mode the
// source first requests cover, waits for cover_ack_toggle, loads the back
// buffer, and then publishes candidate_toggle_async. Actual reader acceptance
// still gates reveal. Neither video timing nor the audio stream is stopped.''')
s=s.replace(' parameter STEP=32',' parameter STEP=32,\n parameter COVER_BEFORE_LOAD=0,\n parameter CLOSE_STEP=STEP, OPEN_STEP=STEP,\n parameter [23:0] MASK_COLOR=24\'d0')
s=s.replace(' input wire commit_ack_toggle,',' input wire commit_ack_toggle,\n input wire cover_request_toggle_async,\n output reg cover_ack_toggle,')
s=s.replace(" localparam IDLE=2'd0,CLOSE=2'd1,WAIT_ACK=2'd2,OPEN=2'd3;\n reg [1:0] phase,locked_mode;", " localparam IDLE=3'd0,CLOSE=3'd1,WAIT_ACK=3'd2,OPEN=3'd3,WAIT_LOAD=3'd4;\n reg [2:0] phase;\n reg [1:0] locked_mode;\n reg accepted_cover;")
s=s.replace('reg [1:0] candidate_sync;', 'reg [1:0] candidate_sync,cover_sync;')
s=s.replace('accepted_toggle<=0;candidate_sync<=0;forwarded_commit_toggle<=0;', 'accepted_toggle<=0;candidate_sync<=0;forwarded_commit_toggle<=0;\n   accepted_cover<=0;cover_sync<=0;cover_ack_toggle<=0;')
s=s.replace('candidate_sync<={candidate_sync[0],candidate_toggle_async};','candidate_sync<={candidate_sync[0],candidate_toggle_async};\n   cover_sync<={cover_sync[0],cover_request_toggle_async};')
a=s.index('   case(phase)');b=s.index('   o_hs<=i_hs;',a)
s=s[:a]+'''   case(phase)
    IDLE: if(COVER_BEFORE_LOAD)begin
     if(cover_sync[1]!=accepted_cover &&
        forwarded_commit_toggle==commit_ack_toggle)begin
      accepted_cover<=cover_sync[1];
      locked_mode<=enable?mode:2'd0;offset<=0;phase<=CLOSE;
     end
    end else if(candidate_sync[1]!=accepted_toggle &&
                forwarded_commit_toggle==commit_ack_toggle)begin
     accepted_toggle<=candidate_sync[1];
     if(!enable || mode==0 || mode==3)
      forwarded_commit_toggle<=candidate_sync[1];
     else begin locked_mode<=mode;offset<=0;phase<=CLOSE;end
    end
    CLOSE: if(frame_start)begin
     if(offset+CLOSE_STEP>=WIDTH || locked_mode==0 || locked_mode==3)begin
      offset<=WIDTH;
      if(COVER_BEFORE_LOAD)begin cover_ack_toggle<=accepted_cover;phase<=WAIT_LOAD;end
      else begin forwarded_commit_toggle<=accepted_toggle;phase<=WAIT_ACK;end
     end else offset<=offset+CLOSE_STEP;
    end
    WAIT_LOAD: if(candidate_sync[1]!=accepted_toggle)begin
     accepted_toggle<=candidate_sync[1];
     forwarded_commit_toggle<=candidate_sync[1];phase<=WAIT_ACK;
    end
    WAIT_ACK: if(frame_start && commit_ack_toggle==forwarded_commit_toggle)begin
     if(locked_mode==0 || locked_mode==3)begin offset<=0;phase<=IDLE;end
     else begin offset<=WIDTH>OPEN_STEP?WIDTH-OPEN_STEP:0;phase<=OPEN;end
    end
    OPEN: if(frame_start)begin
     if(offset<=OPEN_STEP)begin offset<=0;phase<=IDLE;end
     else offset<=offset-OPEN_STEP;
    end
    default:begin phase<=IDLE;offset<=0;end
   endcase
'''+s[b:]
s=s.replace('base_rgb_q<=0;\n   else base_rgb_q<=i_rgb;', 'base_rgb_q<=MASK_COLOR;\n   else base_rgb_q<=i_rgb;')
p.write_text(s)
