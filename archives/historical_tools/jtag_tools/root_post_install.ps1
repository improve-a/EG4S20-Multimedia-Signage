$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$id='USB\VID_0547&PID_1002\7&2BAF49FB&0&3'
$dev=Get-PnpDevice -InstanceId $id
$props=@(Get-PnpDeviceProperty -InstanceId $id | Where-Object {$_.KeyName -in @('DEVPKEY_Device_Service','DEVPKEY_Device_DriverInfPath','DEVPKEY_Device_DriverVersion','DEVPKEY_Device_ProblemCode','DEVPKEY_Device_IsRebootRequired','DEVPKEY_Device_HardwareIds','DEVPKEY_Device_IsPresent')} | Select-Object KeyName,Data)
$setup=[string](Get-Content 'C:\Windows\INF\setupapi.dev.log' -Tail 240 | Out-String)
$setup | Out-File "$root\root_setupapi_tail.txt" -Encoding utf8
$procs=@(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | ForEach-Object {
    $probe=''; if($_.CommandLine -match '-EncodedCommand\s+([A-Za-z0-9+/=]+)') {try {$probe=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1]))}catch{}}
    if($probe -match 'c_programmer_docs|r.Scripts=@\(Get-ChildItem') {[pscustomobject]@{pid=$_.ProcessId;created=$_.CreationDate;command_sha_note='Worker C broad readonly search remains';probe=$probe}}
})
$result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;device=($dev | Select-Object InstanceId,FriendlyName,Status,Problem);properties=$props;orphan_readonly_probes=$procs;setupapi_tail=$setup}
$result | ConvertTo-Json -Depth 5 | Tee-Object -FilePath "$root\root_post_install.json"
