# Reproduce the fix_round/media short tests on the Windows host (read-only RTL,
# outputs only under D:\FPGA\EG4S20-NoBot-Fix-20261020\media).
# Run from a PowerShell prompt on the build host after copying media\tb and
# media\tools to D:\FPGA\EG4S20-NoBot-Fix-20261020\media.
$ErrorActionPreference = "Stop"
$IV   = "C:/iverilog/bin/iverilog.exe"
$VVP  = "C:/iverilog/bin/vvp.exe"
$HS   = "D:/FPGA/EG4S20-NoBot-RCA-20261020/builds/rca_locked_only_001/work/design/user_source/hdl_source"
$T    = "D:/FPGA/EG4S20-NoBot-Fix-20261020/media/tb"
$O    = "D:/FPGA/EG4S20-NoBot-Fix-20261020/media/out"
New-Item -ItemType Directory -Force $O | Out-Null

$common = @(
  "$T/tb_commit_chain.v", "$HS/display_commit.v", "$HS/ext/video_transition.v"
)
& $IV -g2012 -o "$O/tb_commit_chain_0.vvp" -s tb_commit_chain @common
& $VVP "$O/tb_commit_chain_0.vvp" | Tee-Object "$O/commit_phase_0.log"
foreach ($p in 3,7,13,19) {
  & $IV -g2012 "-Ptb_commit_chain.PHASE_NS=$p" -o "$O/tb_commit_chain_$p.vvp" -s tb_commit_chain @common
  & $VVP "$O/tb_commit_chain_$p.vvp" | Tee-Object "$O/commit_phase_$p.log"
}
foreach ($l in 0,1,50,299,300) {
  & $IV -g2012 "-Ptb_commit_chain.LOAD_CYCLES=$l" -o "$O/tb_cc_l$l.vvp" -s tb_commit_chain @common
  & $VVP "$O/tb_cc_l$l.vvp" | Tee-Object "$O/commit_load_$l.log"
}

$fr = @(
  "$T/tb_fr_fault.v", "$HS/SD/frame_read_write.v", "$HS/SD/frame_fifo_read.v",
  "$HS/SD/frame_fifo_write.v", "$HS/IP/afifo_16_32_256.v", "$HS/IP/afifo_32_16_256.v"
)
& $IV -g2012 -o "$O/tb_fr_fault.vvp" -s tb_fr_fault @fr
& $VVP "$O/tb_fr_fault.vvp" | Tee-Object "$O/fr_fault.log"

& $IV -g2012 -o "$O/tb_audio_mux.vvp" -s tb_audio_mux "$T/tb_audio_mux.v" "$HS/ext/audio_output_mux.v"
& $VVP "$O/tb_audio_mux.vvp" | Tee-Object "$O/audio_mux.log"

& $IV -g2012 -o "$O/tb_audio_fifo_seq.vvp" -s tb_audio_fifo_seq "$T/tb_audio_fifo_seq.v" "$HS/ext/audio_async_fifo.v"
& $VVP "$O/tb_audio_fifo_seq.vvp" | Tee-Object "$O/audio_fifo_seq_20.log"
foreach ($r in 0,200,400) {
  & $IV -g2012 "-Ptb_audio_fifo_seq.AUDIO_REL_NS=$r" -o "$O/tb_audio_fifo_seq_$r.vvp" -s tb_audio_fifo_seq "$T/tb_audio_fifo_seq.v" "$HS/ext/audio_async_fifo.v"
  & $VVP "$O/tb_audio_fifo_seq_$r.vvp" | Tee-Object "$O/audio_fifo_seq_$r.log"
}
& $IV -g2012 -o "$O/tb_audio_fifo_rdc.vvp" -s tb_audio_fifo_rdc "$T/tb_audio_fifo_rdc.v" "$HS/ext/audio_async_fifo.v"
& $VVP "$O/tb_audio_fifo_rdc.vvp" | Tee-Object "$O/audio_fifo_rdc.log"
