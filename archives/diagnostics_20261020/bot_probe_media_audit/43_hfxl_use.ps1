[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r='D:\FPGA\EG4S20-Multimedia-Signage'
Write-Output "=== ENABLE_HFXL in old sd_card_bmp ==="
Select-String -LiteralPath "$r\rtl\SD\sd_card_bmp.v" -Pattern 'ENABLE_HFXL|bmp_scale|ENABLE_LAYER_RESOURCES' | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== hfxl_extent_ok acceptance in bmp_scale ==="
Select-String -LiteralPath "$r\rtl\ext\bmp_scale.v" -Pattern 'hfxl_extent_ok|header_ok|accept|locator'_x0000_ | Select-Object -First 12 | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Select-String -LiteralPath "$r\rtl\ext\bmp_scale.v" -Pattern 'hfxl_extent_ok' | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== DONE ==="
