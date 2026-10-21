[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== G:\anlu top ==="
Get-ChildItem -LiteralPath 'G:\anlu' -Force -ErrorAction SilentlyContinue | ForEach-Object { "{0} {1}" -f $(if($_.PSIsContainer){'DIR '}else{'FILE'}), $_.Name }
Write-Output "=== programmer-ish exe/dll under G:\anlu (depth 3) ==="
Get-ChildItem -LiteralPath 'G:\anlu' -Recurse -File -ErrorAction SilentlyContinue -Depth 3 |
  Where-Object { $_.Name -match 'prog|jtag|usb|bit' } | ForEach-Object { "{0,10} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd'), $_.FullName }
Write-Output "=== G:\anlu\bin listing (first 60) ==="
Get-ChildItem -LiteralPath 'G:\anlu\bin' -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 60 | ForEach-Object { "{0,10} {1}" -f $_.Length, $_.Name }
Write-Output "=== DONE ==="
