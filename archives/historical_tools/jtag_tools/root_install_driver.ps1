$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$dir="$root\driver_candidate"
$expected=@{'cyusb.inf'='0680B756F4457E4E399D291AA0FC06DF4A1122058844C8E851B0EDAAAAE2E6FE';'cyusb.sys'='D78C2F28340E33F19549AB8C284A8C7783C55C9B483D1B2EB00FBA728D097BAA';'driver.cat'='5FEFF0324E3B62ACF2F65BA10A7DF38B166B54FC0813BEC641667230D3EBB721'}
foreach($name in $expected.Keys) {if((Get-FileHash "$dir\$name" -Algorithm SHA256).Hash -ne $expected[$name]) {throw "Hash mismatch: $name"}}
foreach($name in @('cyusb.sys','driver.cat')) {if((Get-AuthenticodeSignature "$dir\$name").Status -ne 'Valid') {throw "Signature not Valid: $name"}}
$targets=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -like 'USB\VID_0547&PID_1002\*'})
if($targets.Count -ne 1 -or $targets[0].InstanceId -ne 'USB\VID_0547&PID_1002\7&2BAF49FB&0&3') {throw 'Target identity changed; stop'}
$marker="$root\root_install_attempt.json"
if(Test-Path $marker) {throw 'Install already attempted; inspect logs before any retry'}
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;action='pnputil /add-driver driver_candidate\cyusb.inf /install';target=$targets[0].InstanceId} | ConvertTo-Json | Set-Content $marker -Encoding utf8
$sw=[Diagnostics.Stopwatch]::StartNew()
$out=& pnputil /add-driver "$dir\cyusb.inf" /install 2>&1
$ec=$LASTEXITCODE
$sw.Stop()
$out | Out-File "$root\root_install_driver.txt" -Encoding utf8
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;pnputil_exit=$ec;wall_seconds=$sw.Elapsed.TotalSeconds;output=($out | Out-String)}
$r | ConvertTo-Json -Depth 4 | Tee-Object -FilePath "$root\root_install_result.json"
exit $ec
