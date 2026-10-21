$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$os=Get-CimInstance Win32_OperatingSystem
$devices=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -like 'USB\VID_0547&PID_1002\*'} | ForEach-Object {
 $d=$_;[ordered]@{id=$d.InstanceId;name=$d.FriendlyName;status=$d.Status;properties=@(Get-PnpDeviceProperty -InstanceId $d.InstanceId | Where-Object {$_.KeyName -match 'HardwareIds|ProblemCode|ProblemStatus|IsPresent|IsRebootRequired|DriverInfPath|DriverVersion|DriverProvider|Device_Service|Device_Stack|LocationPaths'} | Select-Object KeyName,Data)}
})
$svc=@(Get-CimInstance Win32_SystemDriver -Filter "Name='CYUSB'" | Select-Object Name,State,Started,StartMode,PathName)
$events=@()
foreach($log in @('Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-Kernel-PnP/Configuration','System')) {
 $events+=@(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=$os.LastBootUpTime} -ErrorAction SilentlyContinue | Where-Object {$_.Message -match 'CYUSB|VID_0547|PID_1002'} | Select-Object TimeCreated,LogName,Id,LevelDisplayName,Message)
}
$exe='G:\anlu\bin\bw_commands_prompt.exe'
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;boot_utc=$os.LastBootUpTime.ToUniversalTime().ToString('o');devices=$devices;cyusb=$svc;events_since_boot=$events;programmer_cli=$exe;programmer_sha256=(Get-FileHash $exe -Algorithm SHA256).Hash;programmer_gui_exists=(Test-Path 'G:\anlu\bin\bw.exe');active_programmers=@(Get-Process -Name bw,bw_commands_prompt,hwserver -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,SessionId)}
$r | ConvertTo-Json -Depth 7 | Tee-Object -FilePath "$root\${stamp}_recovered_driver.json"
