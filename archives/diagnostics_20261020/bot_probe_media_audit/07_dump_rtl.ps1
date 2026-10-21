[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r = 'D:\FPGA\EG4S20-Multimedia-Signage'
foreach ($f in @('rtl\ext\html_resource_locator.v','rtl\ext\html_scene_loader.v')) {
  Write-Output ("===== " + $f + " =====")
  Get-Content -LiteralPath (Join-Path $r $f) -Raw -Encoding UTF8
  Write-Output ""
}
Write-Output "=== SD dir ==="
Get-ChildItem -LiteralPath "$r\rtl\SD" -File | ForEach-Object { "{0,9} {1}" -f $_.Length, $_.Name }
Write-Output "=== DONE ==="
