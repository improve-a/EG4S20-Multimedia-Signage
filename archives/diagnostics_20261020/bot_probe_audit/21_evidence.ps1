[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
function Keys($p, $label) {
  Write-Output ("=== $label keys ===")
  $o = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
  $o.PSObject.Properties | ForEach-Object {
    $v = $_.Value
    $kind = if ($v -is [array]) { 'array[' + $v.Count + ']' } elseif ($v -is [pscustomobject]) { 'object' } else { 'scalar' }
    Write-Output ("  " + $_.Name + " : " + $kind)
  }
  return $o
}
$cdc = Keys 'D:\FPGA\EG4S20-NoBot-HDMIProbe\evidence\hdmi_probe\mapped_cdc_final.json' 'mapped_cdc_final'
$s = ($cdc | ConvertTo-Json -Depth 8 -Compress)
Write-Output ("CDC JSON chars=" + $s.Length)
Write-Output $s.Substring(0, [Math]::Min(2000, $s.Length))
Write-Output "=== DONE ==="
