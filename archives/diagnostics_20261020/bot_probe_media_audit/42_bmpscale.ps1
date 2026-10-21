[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r='D:\FPGA\EG4S20-Multimedia-Signage'
Write-Output "=== top bmp_scale instantiation params ==="
Select-String -LiteralPath "$r\rtl\top_tf_hdmi_audio.v" -Pattern 'bmp_scale|ENABLE_HFXL' | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== bmp_scale.v HFXL gate (lines 120-165) ==="
$l = Get-Content -LiteralPath "$r\rtl\ext\bmp_scale.v" -Encoding UTF8
$l[119..164] | ForEach-Object -Begin {$i=120} -Process { "{0,4}: {1}" -f $i, $_; $i++ }
Write-Output "=== DONE ==="
