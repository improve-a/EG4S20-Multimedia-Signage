[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$p='D:\FPGA\EG4S20-Multimedia-Signage\rtl\top_tf_hdmi_audio.v'
Write-Output "=== sd_card_bmp instantiation (old top) ==="
$lines = Get-Content -LiteralPath $p -Encoding UTF8
$idx = (Select-String -LiteralPath $p -Pattern 'sd_card_bmp' | Select-Object -First 1).LineNumber
if ($idx) { $lines[($idx-1)..([math]::Min($idx+28,$lines.Count-1))] | ForEach-Object { $_ } }
Write-Output "=== NoBot legacy_exhibit_media scan params ==="
$q='D:\FPGA\EG4S20-NoBot-HDMIProbe\rtl\ext\legacy_exhibit_media.v'
Select-String -LiteralPath $q -Pattern 'SCAN_|scan_max|scan_start|ENABLE_' | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== DONE ==="
