$ErrorActionPreference='Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$os=Get-CimInstance Win32_OperatingSystem
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$r=[ordered]@{time_utc=[DateTime]::UtcNow.ToString('o');pid=$PID;host=$env:COMPUTERNAME;user=[Security.Principal.WindowsIdentity]::GetCurrent().Name;admin=$admin;os=$os.Caption;version=$os.Version;build=$os.BuildNumber;ps=$PSVersionTable.PSVersion.ToString();source_exists=(Test-Path -LiteralPath 'G:\macshare\嵌赛\HX4S20_Contest_202606\1_安路开发工具和常用软件');td_known_path=(Test-Path 'G:\anlu\bin\td_commands_prompt.exe');remote_root=$root}
$r | ConvertTo-Json | Tee-Object -FilePath "$root\baseline.json"
