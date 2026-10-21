[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$p='D:\FPGA\EG4S20-NoBot-HDMIProbe\rtl\SD\bmp_read.v'
$l = Get-Content -LiteralPath $p -Encoding UTF8
$l[128..165] | ForEach-Object -Begin {$i=129} -Process { "{0,4}: {1}" -f $i, $_; $i++ }
Write-Output "=== bmp_scale_read HFXL gate ==="
Select-String -LiteralPath 'D:\FPGA\EG4S20-NoBot-HDMIProbe\rtl\ext\bmp_scale.v' -Pattern 'ENABLE_HFXL' | Select-Object -First 8 | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== DONE ==="
