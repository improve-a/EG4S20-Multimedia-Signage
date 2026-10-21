[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ProgressPreference='SilentlyContinue'
$ErrorActionPreference='Continue'
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$present=@(Get-PnpDevice -PresentOnly)
$present | Select-Object Status,Class,FriendlyName,InstanceId,Problem | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$root\a_all_present.json"
$all=@(Get-PnpDevice)
$candidates=@($all | Where-Object { $_.InstanceId -match '^(USB|FTDIBUS|BTHENUM)' -or $_.Class -eq 'Ports' -or $_.Status -eq 'Error' })
$drivers=@(Get-CimInstance Win32_PnPSignedDriver)
$details=@(foreach($d in $candidates) {
  $props=@(Get-PnpDeviceProperty -InstanceId $d.InstanceId -ErrorAction SilentlyContinue)
  $map=@{}; foreach($p in $props){$map[$p.KeyName]=$p.Data}
  $dr=@($drivers | Where-Object { $_.DeviceID -eq $d.InstanceId } | Select-Object DeviceName,DriverProviderName,DriverVersion,DriverDate,InfName,IsSigned,Signer,Manufacturer)
  [PSCustomObject]@{InstanceId=$d.InstanceId; FriendlyName=$d.FriendlyName;Class=$d.Class;Status=$d.Status;Problem=$d.Problem;Present=($present.InstanceId -contains $d.InstanceId);HardwareIds=$map['DEVPKEY_Device_HardwareIds'];CompatibleIds=$map['DEVPKEY_Device_CompatibleIds'];Service=$map['DEVPKEY_Device_Service'];Parent=$map['DEVPKEY_Device_Parent'];LocationInfo=$map['DEVPKEY_Device_LocationInfo'];LocationPaths=$map['DEVPKEY_Device_LocationPaths'];ContainerId=$map['DEVPKEY_Device_ContainerId'];BusReportedDeviceDesc=$map['DEVPKEY_Device_BusReportedDeviceDesc'];ProblemCode=$map['DEVPKEY_Device_ProblemCode'];DriverInfPath=$map['DEVPKEY_Device_DriverInfPath'];DriverProvider=$map['DEVPKEY_Device_DriverProvider'];DriverVersion=$map['DEVPKEY_Device_DriverVersion'];Driver=$dr}
})
$details | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 "$root\a_usb_devices.json"
Get-CimInstance Win32_SerialPort | Select-Object DeviceID,Name,Description,PNPDeviceID,Status | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$root\a_serial_ports.json"
Get-CimInstance Win32_USBControllerDevice | Select-Object Antecedent,Dependent | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 "$root\a_usb_associations.json"
& pnputil /enum-devices /connected /class USB /drivers 2>&1 | Out-File -Encoding UTF8 "$root\a_pnputil_usb.txt"
& pnputil /enum-devices /problem /drivers 2>&1 | Out-File -Encoding UTF8 "$root\a_pnputil_problems.txt"
Write-Output ('PRESENT_COUNT='+$present.Count+' RELEVANT_COUNT='+$details.Count)
Write-Output 'PRESENT_RELEVANT:'
$details | Where-Object Present | Select-Object InstanceId,FriendlyName,Class,Status,ProblemCode,Service,DriverInfPath,DriverProvider,DriverVersion,HardwareIds,Parent,LocationPaths | ConvertTo-Json -Depth 6
Write-Output 'HISTORICAL_RELEVANT:'
$details | Where-Object { -not $_.Present } | Select-Object InstanceId,FriendlyName,Class,Status,Service,DriverInfPath | ConvertTo-Json -Depth 6
