[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$report = [ordered]@{TimeUTC=(Get-Date).ToUniversalTime().ToString('o');ProcessId=$PID}
$report.Registry = @(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object {($_.DisplayName+' '+$_.InstallLocation) -match 'Tang|Anlu|Anlogic|TD |FTDI|CH34|WCH|USB Driver|COMTransmit'} | Select-Object DisplayName,DisplayVersion,InstallLocation,Publisher,UninstallString)
$report.TDRoot = @(Get-ChildItem 'G:\anlu' -Force | Select-Object Name,Mode,LastWriteTime)
$report.Binaries = @(Get-ChildItem 'G:\anlu\bin' -File -Recurse | Where-Object {$_.Name -match 'program|jtag|download|td_commands|td.exe|version|ftdi|d2xx|usb'} | ForEach-Object {[pscustomobject]@{Path=$_.FullName;Length=$_.Length;Version=$_.VersionInfo.FileVersion;Product=$_.VersionInfo.ProductVersion;Description=$_.VersionInfo.FileDescription}})
$report.DriverFiles = @(Get-ChildItem 'G:\anlu' -File -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.Extension -in '.inf','.cat','.sys' -or $_.Name -match 'version|release|manifest|program.*(pdf|tcl|txt)$|jtag.*(pdf|tcl|txt)$'} | Select-Object FullName,Length)
$report.InstalledThirdPartyDrivers = @(Get-WindowsDriver -Online | Where-Object {($_.ProviderName+' '+$_.OriginalFileName+' '+$_.ClassName) -match 'FTDI|WCH|CH34|WinUSB|Anlogic|Anlu|libusb|USB'} | Select-Object Driver,OriginalFileName,ProviderName,ClassName,Date,Version)
$report.SignedPnPDrivers = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object {($_.DeviceName+' '+$_.DriverProviderName+' '+$_.InfName+' '+$_.DeviceID) -match 'FTDI|CH34|WCH|Anlogic|Anlu|WinUSB|VID_0403|VID_1A86'} | Select-Object DeviceName,DeviceID,InfName,DriverVersion,DriverProviderName,IsSigned,Signer)
$report | ConvertTo-Json -Depth 8
