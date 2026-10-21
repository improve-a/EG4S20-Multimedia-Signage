[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$repo = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
$C = '42de1dbe4a20ca78f28be54c4bf41bd0dd814481'
$workAl = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\td_project\hx4s20_basic.al'
$gitAl = (git -C $repo --no-pager show ($C + ':project/td_project/hx4s20_basic.al')) -join "`n"
$workTxt = [IO.File]::ReadAllText($workAl)
Write-Output ("git .al lines=" + (($gitAl -split "`n").Count) + " work .al lines=" + (($workTxt -split "`n").Count))
$gitFiles = [regex]::Matches($gitAl, '<File Path="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$workFiles = [regex]::Matches($workTxt, '<File Path="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
Write-Output ("git file entries=" + $gitFiles.Count + " work file entries=" + $workFiles.Count)
Write-Output ("ONLY_IN_GIT_AL: " + (($gitFiles | Where-Object { $workFiles -notcontains $_ }) -join ' | '))
Write-Output ("ONLY_IN_WORK_AL: " + (($workFiles | Where-Object { $gitFiles -notcontains $_ }) -join ' | '))
Write-Output "=== ADC/SDC entries in work .al ==="
[regex]::Matches($workTxt, '<(ADC_FILE|SDC_FILE|Timing|Constraint)[^>]*>\s*<File Path="([^"]+)"') | ForEach-Object { Write-Output ($_.Groups[1].Value + ' ' + $_.Groups[2].Value) }
Write-Output "=== work .al hash ==="
(Get-FileHash -Algorithm SHA256 -LiteralPath $workAl).Hash.ToLower()
Write-Output "=== DONE ==="
