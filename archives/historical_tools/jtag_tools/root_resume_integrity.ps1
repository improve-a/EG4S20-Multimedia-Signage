$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_usb_jtag_harness_20261013'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$repo='C:\Windows\System32\DriverStore\FileRepository\cyusb.inf_amd64_18a6ec6c15325ea9'
$files=@()
foreach($f in @("$repo\cyusb.inf","$repo\cyusb.sys","$repo\driver.cat",'C:\Windows\INF\oem357.inf','C:\Windows\System32\drivers\CYUSB.sys')) {
 if(Test-Path $f) {$sig=Get-AuthenticodeSignature $f;$files+=[ordered]@{path=$f;sha256=(Get-FileHash $f -Algorithm SHA256).Hash;signature=$sig.Status.ToString();status_message=$sig.StatusMessage;signer=$sig.SignerCertificate.Subject;issuer=$sig.SignerCertificate.Issuer;thumbprint=$sig.SignerCertificate.Thumbprint;timestamp_signer=$sig.TimeStamperCertificate.Subject}}
}
$signtools=@(Get-Command signtool.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
if(!$signtools.Count) {foreach($folder in @('C:\Program Files (x86)\Windows Kits\10\bin','C:\Program Files\Windows Kits\10\bin')) {if(Test-Path $folder){$signtools+=@(Get-ChildItem $folder -Filter signtool.exe -File -Recurse | Where-Object {$_.FullName -match '\\x64\\'} | Select-Object -ExpandProperty FullName)}}}
$verification=@()
if($signtools.Count){$st=$signtools | Sort-Object -Descending | Select-Object -First 1;foreach($policy in @('/pa','/kp')) {$out=& $st verify $policy /v /c "$repo\driver.cat" "$repo\cyusb.sys" 2>&1;$ec=$LASTEXITCODE;$verification+=[ordered]@{tool=$st;policy=$policy;exit=$ec;output=($out|Out-String)}}}
$secureBoot=$null;try {$secureBoot=Confirm-SecureBootUEFI}catch{$secureBoot=$_.Exception.Message}
$svc=@(Get-CimInstance Win32_SystemDriver -Filter "Name = 'CYUSB'" | Select-Object Name,State,Started,StartMode,PathName,Status)
$pnputil=& pnputil /enum-devices /instanceid 'USB\VID_0547&PID_1002\7&2BAF49FB&0&3' /drivers 2>&1
$nativeExit=$LASTEXITCODE
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;files=$files;signtools=$signtools;verification=$verification;secure_boot=$secureBoot;service=$svc;pnputil_exit=$nativeExit;pnputil=($pnputil | Out-String)}
$r|ConvertTo-Json -Depth 6|Tee-Object -FilePath "$root\${stamp}_resume_integrity.json"
