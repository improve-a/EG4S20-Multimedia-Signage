$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$id='USB\VID_0547&PID_1002\7&2BAF49FB&0&3'
$out=& pnputil /enum-devices /instanceid $id /drivers 2>&1
$ec=$LASTEXITCODE
$out | Out-File "$root\root_driver_candidates.txt" -Encoding utf8
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;pnputil_exit=$ec;output=($out | Out-String)} | ConvertTo-Json -Depth 5
