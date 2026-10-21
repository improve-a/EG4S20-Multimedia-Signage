[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$tcl = (Join-Path $env:TEMP 'bpma_enum.tcl').Replace('\','/')
@'
puts "ENUM_BEGIN"
if {[catch {list_cable} c]} { puts stderr "LIST_CABLE_ERROR $c"; exit 2 }
puts "LIST_CABLE_RETURN $c"
if {[catch {read_device_id -cable 0} d]} { puts stderr "READ_ID_ERROR $d"; exit 3 }
puts "READ_ID_RETURN $d"
puts "ENUM_END"
exit 0
'@ | Set-Content -LiteralPath $tcl -Encoding ASCII
Write-Output ("TCL_PATH=" + $tcl)
& 'G:\anlu\bin\bw_commands_prompt.exe' $tcl
Write-Output ("BW_EXIT=" + $LASTEXITCODE)
Remove-Item -LiteralPath $tcl -Force -ErrorAction SilentlyContinue
Write-Output "=== DONE ==="
