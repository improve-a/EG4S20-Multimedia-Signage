# Analyze actual SPI initialization timing in a NEW directory and NEW TD process.
# Root supplies ANLOGIC_DB_SOURCE and ANLOGIC_PROD_SDC from the SAME completed run.
# Changes only IO analysis for the real RTL initialization divider248 mode.
foreach k {ANLOGIC_DB_SOURCE ANLOGIC_PROD_SDC} {
 if {![info exists ::env($k)]} {error "Required environment variable: $k"}
 if {![file isfile $::env($k)]} {error "Missing input: $::env($k)"}
}
if {[file exists init_pr.db] || [file exists init_mode.sdc]} {error "Use a fresh empty diagnostic directory"}
file copy $::env(ANLOGIC_DB_SOURCE) init_pr.db
set f [open $::env(ANLOGIC_PROD_SDC) r]
set io_sdc [read $f]
close $f
set replacements {
 {-divide_by 8 [get_ports {sd_dclk}]} {-divide_by 500 [get_ports {sd_dclk}]}
 {-clock_fall -max 16.000 [get_ports {sd_miso}]} {-clock_fall -max 52.000 [get_ports {sd_miso}]}
 {set_multicycle_path 4 -setup -end -from [get_ports {sd_miso}]} {set_multicycle_path 250 -setup -end -from [get_ports {sd_miso}]}
 {set_multicycle_path 7 -hold -end -from [get_ports {sd_miso}]} {set_multicycle_path 499 -hold -end -from [get_ports {sd_miso}]}
 {set_multicycle_path 4 -setup -start -to [get_ports {sd_mosi sd_ncs}]} {set_multicycle_path 250 -setup -start -to [get_ports {sd_mosi sd_ncs}]}
 {set_multicycle_path 7 -hold -start -to [get_ports {sd_mosi sd_ncs}]} {set_multicycle_path 499 -hold -start -to [get_ports {sd_mosi sd_ncs}]}
}
foreach {old new} $replacements {
 set first [string first $old $io_sdc]
 if {$first < 0 || [string first $old $io_sdc [expr {$first+1}]] >= 0} {error "Expected exactly one original IO constraint: $old"}
 set io_sdc [string map [list $old $new] $io_sdc]
}
set f [open init_mode.sdc {WRONLY CREAT EXCL}]
puts $f $io_sdc
close $f
import_device eagle_s20.db -package EG4S20BG256
import_db init_pr.db
write_verilog mapped.v -implement
# Exactly ONE user-SDC replacement in this fresh process; retain inherited IP SDC.
clear_sdc -user
read_sdc init_mode.sdc
update_timing -mode final
report_timing_summary -file init_timing.rpt -ep_num 64 -path_num 2
report_timing_exception -file init_exceptions.rpt -ep_num 128 -path_num 2
report_timing_ignored -file init_ignored.rpt -ep_num 128 -path_num 2
report_clock_summary -file init_clocks.rpt
check_timing -file init_check.rpt
exit 0
