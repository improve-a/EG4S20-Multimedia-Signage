[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($d in @('D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z','D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_retest_20261019T152547Z')) {
  Write-Output ("=== " + $d)
  Get-ChildItem -LiteralPath $d -Recurse -File | Sort-Object FullName | ForEach-Object { "{0,10} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $_.FullName.Substring($d.Length+1) }
}
Write-Output "=== DONE ==="
