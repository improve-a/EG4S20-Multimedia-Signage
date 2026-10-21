[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== G:\anlu\doc ==="
Get-ChildItem -LiteralPath 'G:\anlu\doc' -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
Get-ChildItem -LiteralPath 'G:\anlu\doc' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
Write-Output "=== SWUG pdf names ==="
Get-ChildItem -LiteralPath 'G:\anlu\doc\SWUG' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
Write-Output "=== DONE ==="
