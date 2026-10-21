# TD 6.2.1 Engineer 168116 project-mode flow. No hardware commands.
namespace eval ::codex_hx4s20 {}
set ::codex_hx4s20::root {@ROOT@}
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
 export_flow_script -run syn_1 -file {@RUN_DIR@/exported_syn.tcl}
 export_flow_script -run phy_1 -file {@RUN_DIR@/exported_phy.tcl}
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
 set ::codex_hx4s20::currentStage BITGEN
 ::codex_hx4s20::assert_run phy_1 bitgen
 set ::codex_hx4s20::bits [glob -nocomplain -directory [file join $::codex_hx4s20::runsDir phy_1] *.bit]
 if {![llength $::codex_hx4s20::bits]} {error "No new bitstream in phy_1"}
 ::codex_hx4s20::event BITGEN PASS
 set ::codex_hx4s20::currentStage STA_REPORT
 ::codex_hx4s20::event STA_REPORT RUNNING
 open_run phy_1
 update_timing -mode final
 report_timing_summary -file {@RUN_DIR@/final_timing.rpt}
 report_timing_ignored -file {@RUN_DIR@/ignored_timing.rpt}
 # This report includes every SPI MCP endpoint with full setup/hold paths.
 # Top-level get_ports queries in this installed CLI return empty post-open_run;
 # do not rely on separate report_timing_path filters for coverage.
 report_timing_exception -file {@RUN_DIR@/exceptions.rpt} -ep_num 32 -path_num 2
 report_clock_summary -file {@RUN_DIR@/clocks.rpt}
 check_timing -file {@RUN_DIR@/check_timing.rpt}
 report_area -io_info -file {@RUN_DIR@/final_area.rpt}


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
