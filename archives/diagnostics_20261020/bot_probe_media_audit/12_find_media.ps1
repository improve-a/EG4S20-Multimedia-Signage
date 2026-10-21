[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== D:\FPGA top ==="
Get-ChildItem -LiteralPath 'D:\FPGA' -Directory -Force | ForEach-Object { $_.Name }
Write-Output "=== images under D:\FPGA (depth-limited) ==="
foreach ($d in @('D:\FPGA\EG4S20-NoBot-HDMIProbe','D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-Bot-HDMIProbe','D:\FPGA\EG4S20-NoBot')) {
  if (Test-Path $d) {
    Get-ChildItem -LiteralPath $d -Recurse -File -Filter '*.img' -ErrorAction SilentlyContinue |
      ForEach-Object { "{0,12} {1} {2}  {3}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), ($_.FullName -replace [regex]::Escape('D:\FPGA\'),''), (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
  } else { Write-Output ("MISSING " + $d) }
}
Write-Output "=== no_bot media dirs ==="
foreach ($d in @('D:\FPGA\EG4S20-NoBot\output\html_fidelity\no_bot\media','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\no_bot\media')) {
  Write-Output ("--- " + $d)
  if (Test-Path $d) { Get-ChildItem -LiteralPath $d -File | ForEach-Object { "{0,10} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $_.Name } } else { Write-Output "MISSING" }
}
Write-Output "=== DONE ==="
