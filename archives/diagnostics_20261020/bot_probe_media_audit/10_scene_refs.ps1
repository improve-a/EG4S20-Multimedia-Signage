[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r = 'D:\FPGA\EG4S20-Multimedia-Signage'
Write-Output "=== scene_loader instantiation lines in rtl ==="
Get-ChildItem -LiteralPath "$r\rtl" -Recurse -File -Filter '*.v' |
  Select-String -Pattern 'html_scene_loader|sector[0-5]|scene_sector|BASE_WORDS|SET_ID' |
  ForEach-Object { "{0}:{1}: {2}" -f $_.Filename, $_.LineNumber, $_.Line.Trim() }
Write-Output "=== DONE ==="
