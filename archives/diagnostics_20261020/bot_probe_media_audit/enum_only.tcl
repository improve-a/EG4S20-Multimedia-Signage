puts "ENUM_BEGIN"
if {[catch {list_cable} c]} { puts stderr "LIST_CABLE_ERROR $c"; exit 2 }
puts "LIST_CABLE_RETURN $c"
if {[catch {read_device_id -cable 0} d]} { puts stderr "READ_ID_ERROR $d"; exit 3 }
puts "READ_ID_RETURN $d"
puts "ENUM_END"
exit 0
