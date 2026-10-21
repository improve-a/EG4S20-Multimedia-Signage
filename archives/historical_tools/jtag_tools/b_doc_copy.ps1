[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$ErrorActionPreference='Stop'
$base='G:\macshare\嵌赛\HX4S20_Contest_202606'
$dest='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$items=@(
@{src='1_安路开发工具和常用软件\HX4S20安装驱动文档\安路TD开发工具软件安装教程.docx';name='b_hx4s20_install.docx'},
@{src='3_原理图\开发板原理图\3_Power_and_Config.pdf';name='b_power_config.pdf'},
@{src='3_原理图\开发板原理图\4_GPIO.pdf';name='b_gpio.pdf'})
foreach($i in $items){$s=Join-Path $base $i.src;$d=Join-Path $dest $i.name;Copy-Item -LiteralPath $s -Destination $d;Get-FileHash -LiteralPath $s -Algorithm SHA256 | Select Path,Hash}
Get-Content -LiteralPath (Join-Path $base '1_安路开发工具和常用软件\HX4S20安装驱动文档\安装前先看这个.txt') -Encoding UTF8
Get-ChildItem -LiteralPath $base -Directory | Select Name
Get-ChildItem -LiteralPath (Join-Path $base '1_安路开发工具和常用软件') -Recurse -File -Filter *.inf | ForEach-Object { $_.FullName; Get-Content -LiteralPath $_.FullName | Select-String 'VID_|PID_|DriverVer|Catalog|Provider' }
