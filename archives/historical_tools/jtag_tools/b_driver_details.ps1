[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$ErrorActionPreference='Stop'
$base='G:\macshare\嵌赛\HX4S20_Contest_202606'
$dest='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
Get-ChildItem -LiteralPath $base -Directory | Select-Object -ExpandProperty Name
$drv=Join-Path $base '1_安路开发工具和常用软件\常用软件\常用软件\上位机软件\下载器驱动\driver\win8_10_64'
Get-ChildItem -LiteralPath $drv -File | ForEach-Object {$sig=Get-AuthenticodeSignature -LiteralPath $_.FullName;[pscustomobject]@{Path=$_.FullName;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash;Status=$sig.Status.ToString();Signer=$sig.SignerCertificate.Subject}} | ConvertTo-Json -Depth 4
Get-Content -LiteralPath (Join-Path $drv 'cyusb.inf')
Copy-Item -LiteralPath (Join-Path $base '3_原理图\开发板原理图\6_EX_DEVICE.pdf') -Destination (Join-Path $dest 'b_ex_device.pdf')
Copy-Item -LiteralPath (Join-Path $base '3_原理图\开发板原理图\1_POWER.pdf') -Destination (Join-Path $dest 'b_power.pdf')
Get-ChildItem -LiteralPath $base -Recurse -File | Where-Object {$_.Name -match 'HX4|用户手册|使用手册|实验指导|实验教程|JTAG|jtag'} | Select FullName,Length | ConvertTo-Json -Depth 3
