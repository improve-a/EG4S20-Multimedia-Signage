# TD 6.2.1 Engineer 168116 project-mode flow. No hardware commands.
namespace eval ::codex_hx4s20 {}
set ::codex_hx4s20::root {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001}
if {![info exists ::env(ANLOGIC_RUN_DIR)]} { error "ANLOGIC_RUN_DIR is required" }
set ::codex_hx4s20::runDir [file normalize $::env(ANLOGIC_RUN_DIR)]
set ::codex_hx4s20::projectDir [file join $::codex_hx4s20::root work design td_project]
set ::codex_hx4s20::runsDir [file join $::codex_hx4s20::projectDir hx4s20_basic_Runs]
set ::codex_hx4s20::currentStage LOAD
proc ::codex_hx4s20::event {stage status} {
 set f [open [file join $::codex_hx4s20::runDir stages.tsv] a]
 puts $f "[clock seconds]\t$stage\t$status"
 close $f
 puts "HARNESS_STAGE $stage $status"
 flush stdout
}
proc ::codex_hx4s20::assert_run {name step} {
 set d [file join $::codex_hx4s20::runsDir $name]
 if {[llength [glob -nocomplain -directory $d .*error.f]]} {error "TD error marker in $name"}
 if {![file exists [file join $d .$step.end.f]]} {error "Missing successful TD stage marker: $name/$step"}
}
cd $::codex_hx4s20::projectDir
if {[catch {
 ::codex_hx4s20::event LOAD RUNNING
 puts "HARNESS_EXPECTED TD=6.2.168116 DEVICE=EG4S20BG256 TOP=top"
 version -number
 import_device eagle_s20.db -package EG4S20BG256
 open_project hx4s20_basic.al
 export_flow_script -run syn_1 -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/exported_syn.tcl}
 export_flow_script -run phy_1 -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/exported_phy.tcl}
 ::codex_hx4s20::event LOAD PASS
 set ::codex_hx4s20::currentStage SYN
 ::codex_hx4s20::event SYN RUNNING
 launch_runs syn_1
 wait_run syn_1
 ::codex_hx4s20::assert_run syn_1 opt_gate
 ::codex_hx4s20::event SYN PASS
 set ::codex_hx4s20::currentStage PNR
 ::codex_hx4s20::event PNR RUNNING
 launch_runs phy_1
 wait_run phy_1
 ::codex_hx4s20::assert_run phy_1 opt_route
 ::codex_hx4s20::event PNR PASS
 # Native automatic hold fixing skips this dense design. The documented
 # standalone fix_hold actually repairs routed paths on EG4S20/TD168116.
 # Save its before/after evidence; do not use the phys_opt command that crashed
 # in the isolated baseline experiment. Generate the final bit only afterward.
 open_run phy_1
 update_timing -mode final
 report_timing_summary -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/before_hold_fix.rpt} -ep_num 128 -path_num 2
 set ::codex_hx4s20::currentStage HOLD_FIX
 ::codex_hx4s20::event HOLD_FIX RUNNING
 fix_hold
 update_timing -mode final
 report_timing_summary -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/after_hold_fix.rpt} -ep_num 128 -path_num 2
 export_db [file join $::codex_hx4s20::runsDir phy_1 hx4s20_basic_pr.db]
 ::codex_hx4s20::event HOLD_FIX PASS
 set ::codex_hx4s20::currentStage BITGEN
 bitgen -bit [file join $::codex_hx4s20::runsDir phy_1 hx4s20_basic.bit]
 ::codex_hx4s20::assert_run phy_1 bitgen
 set ::codex_hx4s20::bits [glob -nocomplain -directory [file join $::codex_hx4s20::runsDir phy_1] *.bit]
 if {![llength $::codex_hx4s20::bits]} {error "No new bitstream in phy_1"}
 ::codex_hx4s20::event BITGEN PASS
 set ::codex_hx4s20::currentStage STA_REPORT
 ::codex_hx4s20::event STA_REPORT RUNNING
 update_timing -mode final
 report_timing_summary -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/final_timing.rpt} -ep_num 128 -path_num 2
 report_timing_ignored -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/ignored_timing.rpt} -ep_num 128 -path_num 2
 # Include matched SPI endpoints and reset exceptions. MISO coverage must be
 # independently audited; a zero-match exception is not a passing input path.
 report_timing_exception -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/exceptions.rpt} -ep_num 128 -path_num 2
 report_clock_summary -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/clocks.rpt}
 check_timing -verbose -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/check_timing.rpt}
 report_area -io_info -file {D:/FPGA/EG4S20-Bot-HDMIProbe/output/html_fidelity/builds/bot_hdmi_probe_infer_add_off_001/runs/bot_hdmi_probe_infer_add_off_001/final_area.rpt}


 ::codex_hx4s20::event STA_REPORT PASS
 close_project
 puts "HARNESS_FLOW_COMPLETE"
} message options]} {
 ::codex_hx4s20::event $::codex_hx4s20::currentStage FAIL
 puts "HARNESS_ERROR $message"
 if {[dict exists $options -errorinfo]} {puts [dict get $options -errorinfo]}
 exit 2
}
exit 0
