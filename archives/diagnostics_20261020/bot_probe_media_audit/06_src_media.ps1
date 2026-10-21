[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r = 'D:\FPGA\EG4S20-Multimedia-Signage'
Write-Output "=== TOP LEVEL ==="
Get-ChildItem -LiteralPath $r -Force | ForEach-Object { "{0} {1,10} {2}" -f $(if($_.PSIsContainer){'DIR '}else{'FILE'}), $(if($_.PSIsContainer){''}else{$_.Length}), $_.Name }
Write-Output "=== rtl tree ==="
Get-ChildItem -LiteralPath "$r\rtl" -Recurse -File | ForEach-Object { "{0,9} {1}" -f $_.Length, $_.FullName.Substring($r.Length+1) }
Write-Output "=== evidence manifests count ==="
(Get-ChildItem -LiteralPath "$r\evidence" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Output "=== card-ish files anywhere under repo root (no output) ==="
Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.img','*.iso','*.zip' |
  Where-Object { $_.FullName -notmatch '\\output\\' } |
  ForEach-Object { "{0,12} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $_.FullName.Substring($r.Length+1) }
Write-Output "=== DONE ==="
