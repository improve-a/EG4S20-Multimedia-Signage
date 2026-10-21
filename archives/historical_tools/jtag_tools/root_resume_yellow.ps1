$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$devices=@(Get-PnpDevice | Where-Object {$_.InstanceId -like 'USB\VID_0547&PID_1002\*' -or $_.FriendlyName -like '*Anlogic*'} | ForEach-Object {
  $d=$_
  $p=@(Get-PnpDeviceProperty -InstanceId $d.InstanceId | Where-Object {$_.KeyName -match 'HardwareIds|CompatibleIds|Service$|DriverInfPath|DriverVersion|DriverProvider|ProblemCode|ProblemStatus|IsPresent|IsRebootRequired|DriverDate|MatchingDeviceId|Device_Stack|Device_Parent|LocationPaths'} | Select-Object KeyName,Data)
  [ordered]@{InstanceId=$d.InstanceId;FriendlyName=$d.FriendlyName;Status=$d.Status;Problem=$d.Problem.ToString();Properties=$p}
})
$signed=@(Get-CimInstance Win32_PnPSignedDriver | Where-Object {$_.DeviceID -like 'USB\VID_0547&PID_1002\*'} | Select-Object DeviceID,DeviceName,DriverProviderName,DriverVersion,DriverDate,InfName,IsSigned,Signer)
$entity=@(Get-CimInstance Win32_PnPEntity | Where-Object {$_.PNPDeviceID -like 'USB\VID_0547&PID_1002\*'} | Select-Object PNPDeviceID,Name,ConfigManagerErrorCode,Status,Service)
$file='C:\Windows\System32\drivers\CYUSB.sys'
$sys=$null
if(Test-Path $file) {$s=Get-AuthenticodeSignature $file;$sys=[ordered]@{path=$file;sha256=(Get-FileHash $file -Algorithm SHA256).Hash;signature=$s.Status.ToString();signer=$s.SignerCertificate.Subject;version=(Get-Item $file).VersionInfo.FileVersion}}
$events=@()
foreach($log in @('Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-Kernel-PnP/Configuration','System')) {
  $q=@(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=(Get-Date).AddHours(-2)} -ErrorAction SilentlyContinue)
  $events+=@($q | Where-Object {$_.Message -match 'CYUSB|VID_0547|PID_1002|Anlogic' } | Select-Object TimeCreated,LogName,Id,LevelDisplayName,ProviderName,Message)
}
$guard=@(Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue | Select-Object VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning,CodeIntegrityPolicyEnforcementStatus,UsermodeCodeIntegrityPolicyEnforcementStatus)
$tail=@(Get-Content 'C:\Windows\INF\setupapi.dev.log' -Tail 1800)
$tail | Out-File "$root\${stamp}_resume_setupapi_tail.txt" -Encoding utf8
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;devices=$devices;signed_drivers=$signed;entities=$entity;installed_sys=$sys;events=$events;device_guard=$guard;setupapi_evidence="$root\${stamp}_resume_setupapi_tail.txt"}
$r | ConvertTo-Json -Depth 7 | Tee-Object -FilePath "$root\${stamp}_resume_yellow.json"
