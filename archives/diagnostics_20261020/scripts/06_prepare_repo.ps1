$r='D:\FPGA\EG4S20-NoBot-RCA-20261020\repo'
if(Test-Path $r) {throw 'repo already exists; refusing overwrite'}
git clone --no-hardlinks 'D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020\git\probe_hw_pass_20261020.bundle' $r
if($LASTEXITCODE -ne 0) {throw 'clone failed'}
git -C $r switch -c 'codex/nobot-rca-20261020' 'hw-pass-no-bot-probe-20261020'
if($LASTEXITCODE -ne 0) {throw 'checkout failed'}
git -C $r status --short
Get-Content "$r\harness\windows_job.py" -Encoding UTF8
