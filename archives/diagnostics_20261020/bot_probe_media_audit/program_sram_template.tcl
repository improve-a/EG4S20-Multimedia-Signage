# Template only. Volatile JTAG SRAM; does NOT write flash.
# Replace BIT_PATH with the ported probe bitstream. Use forward slashes.
# Duration with a ~677 KB bit: -spd 6 ~7 s, -spd 3 ~32 s, -spd 1 ~51 s.
puts "PROBE_SRAM_BEGIN"
list_cable
if {[catch {download -bit {BIT_PATH} -mode jtag -spd 3 -cable 0} r]} {
  puts stderr "PROBE_DOWNLOAD_ERROR $r"
  exit 1
}
puts "PROBE_DOWNLOAD_OK"
read_device_id -cable 0
puts "PROBE_SRAM_END"
exit 0
