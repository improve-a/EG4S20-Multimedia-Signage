[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)
$ProgressPreference='SilentlyContinue'
$id='USB\VID_0547&PID_1002\7&2BAF49FB&0&3'
Get-PnpDeviceProperty -InstanceId $id | Select-Object KeyName,Type,Data | ConvertTo-Json -Depth 6
Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceName='USB-JTAG-Cable'" | Select-Object DeviceName,DeviceID,DriverProviderName,DriverVersion,DriverDate,InfName,IsSigned,Signer | ConvertTo-Json -Depth 6
