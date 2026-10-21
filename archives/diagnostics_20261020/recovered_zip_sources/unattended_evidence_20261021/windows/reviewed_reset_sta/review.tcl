import_device eagle_s20.db -package EG4S20BG256
import_db {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta/review_only.db}
update_timing -mode final
report_timing_summary -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta/raw.rpt} -ep_num 128 -path_num 2
set src [get_regs {rst_all_reg}]
if {[llength $src] != 1} {error "Expected exactly one rst_all source register"}
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_10.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_10.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_11.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_11.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_12.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_12.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_13.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_13.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_14.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_14.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_15.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_15.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_16.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_16.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_17.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_17.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_18.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_18.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_19.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_19.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_20.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_20.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_21.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_21.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_22.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_22.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_23.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_23.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# no_q_output_unconsumed_FF_SR_not_data: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_4.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_4.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_5.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_5.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_6.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_6.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_7.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_7.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_8.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_8.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
# second_stage_reset_replica: exact pin; no wildcard/downstream data endpoints.
set sink [get_pins {rs_video/pipe_reg[1]_syn_9.sr}]
puts "AUDITED_PIN rs_video/pipe_reg[1]_syn_9.sr $sink"
if {[llength $sink] != 1} {error "Expected exactly one audited SR pin"}
set_false_path -hold -from $src -to $sink
update_timing -mode final
report_timing_summary -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta/scoped.rpt} -ep_num 128 -path_num 2
report_timing_ignored -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta/ignored.rpt} -ep_num 128 -path_num 2
report_timing_exception -file {D:/FPGA/EG4S20-NoBot-Fix-20261020/reviewed_reset_sta/exceptions.rpt} -ep_num 128 -path_num 2
puts REVIEW_ONLY_COMPLETE
exit 0
