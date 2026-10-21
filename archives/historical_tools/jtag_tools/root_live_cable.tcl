puts "HARNESS_LIVE_CABLE_SCAN_BEGIN"
set rc [catch {list_cable} cables]
puts "LIST_CABLE_RC=$rc"
puts "LIST_CABLE_RESULT=$cables"
puts "HARNESS_LIVE_CABLE_SCAN_END"
if {$rc} {exit 2}
exit
