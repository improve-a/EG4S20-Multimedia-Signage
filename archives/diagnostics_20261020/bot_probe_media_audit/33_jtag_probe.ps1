[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== running TD/bw processes ==="
Get-Process td,td_commands_prompt,bw,bw_commands_prompt,alps -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,StartTime | Format-Table -AutoSize | Out-String -Width 120
Write-Output "=== card / removable media now ==="
Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -or $_.DriveLetter -eq $null } | Select-Object DriveLetter,FileSystemLabel,DriveType,@{n='GB';e={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize | Out-String -Width 120
Get-Disk | Select-Object Number,FriendlyName,BusType,@{n='GB';e={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize | Out-String -Width 120
Write-Output "=== JTAG read-only enumeration ==="
$tcl = Join-Path $env:TEMP 'bot_probe_media_audit_enum.tcl'
@'
puts "ENUM_BEGIN"
if {[catch {list_cable} c]} { puts stderr "LIST_CABLE_ERROR $c"; exit 2 }
puts "LIST_CABLE_RETURN $c"
if {[catch {read_device_id -cable 0} d]} { puts stderr "READ_ID_ERROR $d"; exit 3 }
puts "READ_ID_RETURN $d"
puts "ENUM_END"
exit 0
'@ | Set-Content -LiteralPath $tcl -Encoding ASCII
& 'G:\anlu\bin\bw_commands_prompt.exe' $tcl
Write-Output ("BW_EXIT=" + $LASTEXITCODE)
Remove-Item -LiteralPath $tcl -Force -ErrorAction SilentlyContinue
Write-Output "=== DONE ==="
