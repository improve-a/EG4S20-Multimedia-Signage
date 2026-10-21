[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$ErrorActionPreference='Stop'
$s='G:\macshare\嵌赛\HX4S20_Contest_202606\9_康芯开发板使用手册及实验平台\HX4S20开发板手册-HDL版2410.pdf'
Copy-Item -LiteralPath $s -Destination 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\b_hx4s20_manual.pdf'
Get-FileHash -LiteralPath $s | ConvertTo-Json
