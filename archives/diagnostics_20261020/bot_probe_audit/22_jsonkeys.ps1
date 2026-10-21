[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
function Keys($p, $label) {
  Write-Output ("=== $label ===")
  $o = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
  $o.PSObject.Properties | ForEach-Object {
    $v = $_.Value
    $kind = if ($v -is [array]) { 'array[' + $v.Count + ']' } elseif ($v -is [pscustomobject]) { 'object' } else { 'scalar' }
    Write-Output ("  " + $_.Name + " : " + $kind)
  }
}
Keys 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe\mapped_probe_audit.json' 'mapped_probe_audit'
Keys 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe\baseline_mapped_signal_cells.json' 'baseline_mapped_signal_cells'
Write-Output "=== integration_receipt ==="
Get-Content -LiteralPath 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe\integration_receipt.json'
Write-Output "=== DONE ==="
