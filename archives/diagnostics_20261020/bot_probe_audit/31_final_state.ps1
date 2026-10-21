[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
Write-Output ("HEAD " + (git -C $repo rev-parse HEAD))
Write-Output "STATUS:"
git -C $repo --no-optional-locks status --porcelain
Write-Output ("probe_files_in_repo_since_scan: " + ((Get-ChildItem 'D:\FPGA\EG4S20-NoBot-HDMIProbe' -Filter 'check_probe_port.ps1' -Recurse -ErrorAction SilentlyContinue).Count))
