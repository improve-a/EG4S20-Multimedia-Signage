[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$a='D:\FPGA\EG4S20-Multimedia-Signage\rtl\SD\sd_card_bmp.v'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\rtl\SD\sd_card_bmp.v'
foreach ($p in @($a,$b)) { "{0}  {1}" -f (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash, $p }
Write-Output "=== NoBot scanner constraint lines ==="
Select-String -LiteralPath $b -Pattern 'offset|pixel|131071|scan|bmp_|width|height|dib|bfSize|file_size|sector' | Select-Object -First 70 |
  ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== DONE ==="
