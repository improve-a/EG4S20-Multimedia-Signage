# Diagnostic synthesis only. Does not establish PNR, routed STA or BITGEN PASS.
set root {@ROOT@}
set runDir {@RUN_DIR@}
cd [file join $root work design td_project]
proc event {stage status} {
 global runDir
 set f [open [file join $runDir stages.tsv] a]
 puts $f "[clock seconds]\t$stage\t$status"
 close $f
 puts "HARNESS_STAGE $stage $status"
 flush stdout
}
set stage LOAD
if {[catch {
 puts "HARNESS_SCOPE SYNTHESIS_ONLY TOP=@SYN_TOP@"
 event LOAD RUNNING
 version -number
 import_device eagle_s20.db -package EG4S20BG256
 open_project hx4s20_basic.al
 event LOAD PASS
 set stage SYN
 event SYN RUNNING
 commit_param -step design
 elaborate -top @SYN_TOP@
 set clockFile [open [file join $runDir probe.sdc] w]
 puts $clockFile {create_clock -name probe_clk -period 40 [get_ports clk]}
 close $clockFile
 read_sdc [file join $runDir probe.sdc]
 commit_param -step rtl
 optimize_rtl
 report_area -file {@RUN_DIR@/probe_rtl.area}
 commit_param -step gate
 optimize_gate -packarea
 report_area -file {@RUN_DIR@/probe_gate.area}
 event SYN PASS
 close_project
 puts "HARNESS_FLOW_COMPLETE"
} message options]} {
 event $stage FAIL
 puts "HARNESS_ERROR $message"
 if {[dict exists $options -errorinfo]} {puts [dict get $options -errorinfo]}
 exit 2
}
exit 0
