$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$source='G:\anlu\driver\dl-cable\win10'
$dest='D:\FPGA\hx4s20_usb_jtag_harness_20261013\driver_candidate'
if (Test-Path $dest) {throw 'Candidate directory already exists; inspect instead of overwriting'}
Copy-Item -LiteralPath $source -Destination $dest -Recurse
$files=@(Get-ChildItem $dest -File | ForEach-Object {$sig=Get-AuthenticodeSignature $_.FullName;[ordered]@{path=$_.FullName;sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash;signature=$sig.Status.ToString();signer=$sig.SignerCertificate.Subject}})
$pnp=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -like 'USB\VID_0547&PID_1002\*'} | Select-Object InstanceId,Status,FriendlyName)
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;source=$source;files=$files;inf=(Get-Content "$dest\cyusb.inf" -Raw);targets=$pnp}
$r | ConvertTo-Json -Depth 6 | Tee-Object -FilePath 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_prepare_driver.json'
