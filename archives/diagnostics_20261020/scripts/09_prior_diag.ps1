$d='D:\FPGA\EG4S20-NoBot-HDMIDiag'
Write-Output '=== DIAGNOSTIC DELIVERY RECORDS ==='
Get-ChildItem "$d\output" -Recurse -File | Where-Object { $_.Name -match '^manifest.json$|^.*DELIVERY.*md$|^.*REPORT.*md$' -and $_.FullName -notmatch '\\work\\' } | ForEach-Object { $_.FullName }
Write-Output '=== TRACKED DIAGNOSTIC DOCS ==='
git -C $d log -4 --oneline
Get-ChildItem "$d\docs" -File | Where-Object {$_.Name -match 'hdmi|diag|hardware'} | ForEach-Object {Write-Output "=== $($_.Name) ==="; Get-Content $_.FullName -Encoding UTF8}
