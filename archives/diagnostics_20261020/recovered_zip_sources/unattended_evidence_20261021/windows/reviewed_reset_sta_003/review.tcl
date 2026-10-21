import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta_003/review_only.db}
update_timing -mode final
report_timing_summary -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta_003/raw.rpt} -ep_num 128 -path_num 2
namespace eval ::rca_review {}
set ::rca_review::source [get_regs {rst_all}]
puts [list AUDITED_SOURCE [get_regs -o {rst_all}]]
if {[llength $::rca_review::source] != 1} {error "Expected exactly one reset source"}
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_10.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_10.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_10.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_11.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_11.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_11.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_12.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_12.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_12.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_13.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_13.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_13.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_14.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_14.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_14.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_15.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_15.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_15.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_16.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_16.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_16.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_17.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_17.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_17.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_18.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_18.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_18.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_19.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_19.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_19.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_20.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_20.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_20.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_21.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_21.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_21.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_22.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_22.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_22.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_23.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_23.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_23.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# no_q_output_unconsumed_FF_SR_not_data: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_4.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_4.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_4.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_5.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_5.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_5.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_6.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_6.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_6.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_7.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_7.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_7.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_8.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_8.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_8.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set ::rca_review::sink [get_pins {rs_video/pipe_reg[1]_syn_9.sr}]
puts [list AUDITED_PIN {rs_video/pipe_reg[1]_syn_9.sr} [get_pins -o {rs_video/pipe_reg[1]_syn_9.sr}]]
if {[llength $::rca_review::sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $::rca_review::source -to $::rca_review::sink
update_timing -mode final
report_timing_summary -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta_003/scoped.rpt} -ep_num 128 -path_num 2
report_timing_ignored -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta_003/ignored.rpt} -ep_num 128 -path_num 2
report_timing_exception -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta_003/exceptions.rpt} -ep_num 128 -path_num 2
puts REVIEW_ONLY_COMPLETE
exit 0
