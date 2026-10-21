[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$p = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe\mapped_probe_audit.json'
$o = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
Write-Output "=== cdc_meta_cells (25) ==="
$o.cdc_meta_cells | ForEach-Object { Write-Output ("  " + $_) }
Write-Output "=== cdc_sync_cells (25) ==="
$o.cdc_sync_cells | ForEach-Object { Write-Output ("  " + $_) }
Write-Output "=== selected_drivers ==="
$o.selected_drivers.PSObject.Properties | ForEach-Object { Write-Output ("  " + $_.Name + " -> " + ($_.Value | ConvertTo-Json -Compress -Depth 4)) }
Write-Output "=== DONE ==="
