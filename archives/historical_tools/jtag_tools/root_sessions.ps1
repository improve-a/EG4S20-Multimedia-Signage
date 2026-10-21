$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;processes=@(Get-Process | Where-Object {$_.ProcessName -match 'td|anlogic|program|jtag|ft_prog|usb|COMTransmit'} | Select-Object Id,ProcessName,Path,SessionId,MainWindowTitle);sessions=(& quser 2>&1 | Out-String)}
$r | ConvertTo-Json -Depth 5 | Tee-Object -FilePath 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_sessions.json'
