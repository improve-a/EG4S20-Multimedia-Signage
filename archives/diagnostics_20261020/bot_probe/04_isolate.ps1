$r='D:\FPGA\EG4S20-Multimedia-Signage'
$dest='D:\FPGA\EG4S20-Bot-HDMIProbe'
if(Test-Path $dest){throw 'Destination exists'}
git -C $r worktree add -b codex/bot-hdmi-probe-20261020 $dest 20871da98664b2b674fbcfe94a713359ff9614a1
if($LASTEXITCODE -ne 0){throw 'worktree failed'}
Get-ChildItem "$r\artifacts" -Filter '*timing_fix_20261016_02*' | Select-Object FullName,Length
Get-Content "$r\docs\harness\ROOT_CAUSE_AUDIT_20261018.md" -Encoding UTF8 | Select-Object -First 23
Get-Content "$dest\docs\local_dependencies.json" -Encoding UTF8
Get-Content "$dest\harness\windows_job.py" -Encoding UTF8
