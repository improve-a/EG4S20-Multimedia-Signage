puts "HARNESS: query usage for discovery/read-only commands"
foreach command {list_cable connect_cable read_device_id get_name_from_id} {
    puts "COMMAND=$command"
    puts "TCLPROC=[info procs $command]"
    if {[llength [info procs $command]]} {
        puts "ARGS=[info args $command]"
        puts "BODY=[info body $command]"
    } else {
        set rc [catch {$command -help} result]
        puts "HELP_RC=$rc RESULT=$result"
    }
}
exit
