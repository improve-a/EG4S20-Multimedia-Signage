puts "HARNESS_CABLE_ENUMERATION_BEGIN"
set rc [catch {list_cable} cables]
puts "LIST_CABLE_RC=$rc"
puts "LIST_CABLE_RESULT=$cables"
puts "HARNESS_CABLE_ENUMERATION_END"
if {$rc} {exit 2}
exit
