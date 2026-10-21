$f='D:\FPGA\EG4S20-NoBot-Frozen\probe_hw_pass_20261020'
$r='D:\FPGA\EG4S20-NoBot-Fix-20261020'
$count=0
Get-Content "$f\SHA256SUMS.txt" | ForEach-Object {
 if($_ -match '^([a-f0-9]{64})  (.+)$') {
  $expected=$matches[1];$name=$matches[2]
  if((Get-FileHash -Algorithm SHA256 (Join-Path $f $name)).Hash.ToLower() -ne $expected){throw "Frozen mismatch: $name"}
  $count++
 }
}
Write-Output "FROZEN_VERIFIED $count"
Get-FileHash -Algorithm SHA256 'D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_no_locked_003.bit','D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\rca_locked_only_001.bit'
if(Test-Path "$r\repo") {throw 'Fix repo already exists; inspect before using'}
New-Item -ItemType Directory -Force "$r\scripts","$r\audit" | Out-Null
git clone --no-hardlinks 'D:\FPGA\EG4S20-NoBot-RCA-20261020\delivery\nobot_rca_20261020.bundle' "$r\repo"
if($LASTEXITCODE -ne 0){throw 'clone failed'}
git -C "$r\repo" switch -c 'codex/nobot-fix-20261020' '95de104c0d9c2c953c21cb5068ccffafe76b7c14'
if($LASTEXITCODE -ne 0){throw 'switch failed'}
git -C "$r\repo" status --short
Get-Content "$r\repo\AGENTS.md" -Encoding UTF8
Write-Output '=== TOOLS ==='
Get-Item 'C:\iverilog\bin\iverilog.exe','C:\iverilog\bin\vvp.exe','G:\anlu\bin\td_commands_prompt.exe' | Select-Object FullName,Length
Write-Output '=== ACTIVE TD ==='
Get-Process td_commands_prompt,td,fdp,synpwrap -ErrorAction SilentlyContinue | Select-Object Id,ProcessName
