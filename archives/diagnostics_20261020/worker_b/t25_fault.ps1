$ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
"##### frame_read_write fifo_fault context"
Select-String -Path "$b\SD\frame_read_write.v" -Pattern 'fifo_fault|fault|underflow|overflow|error' | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
"##### html_video_overlay cover/commit lines"
Select-String -Path "$b\ext\html_video_overlay.v" -Pattern 'cover_request|commit|candidate|fault' | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
