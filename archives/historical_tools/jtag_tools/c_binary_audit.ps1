[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding=[Console]::OutputEncoding
$ProgressPreference='SilentlyContinue'
$r=[ordered]@{TimeUTC=(Get-Date).ToUniversalTime().ToString('o');ProcessId=$PID}
$r.Files=@('G:\anlu\bin\bw.exe','G:\anlu\bin\bw_commands_prompt.exe','G:\anlu\bin\td_commands_prompt.exe','G:\anlu\driver\dl-cable\win10\cyusb.inf','G:\anlu\driver\dl-cable\win10\cyusb.sys','G:\anlu\driver\dl-cable\win10\driver.cat') | ForEach-Object {$f=Get-Item $_;$s=Get-AuthenticodeSignature $_;[pscustomobject]@{Path=$_;Length=$f.Length;SHA256=(Get-FileHash $_ -Algorithm SHA256).Hash;Status=$s.Status.ToString();Signer=$s.SignerCertificate.Subject;TimestampSigner=$s.TimeStamperCertificate.Subject}}
$r.BinaryStrings=@('G:\anlu\bin\bw_commands_prompt.exe') | ForEach-Object {$p=$_;$str=[Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($p));[regex]::Matches($str,'[ -~]{5,}') | ForEach-Object {$_.Value} | Where-Object {$_ -match '(?i)(get_cable|scan_chain|scan_device|refresh_cable|detect_cable|list_cable|read_id|read_device|cable_list|cyusb|winusb|^bw|^program|enum_cable|168116|6\.2\.1)' -and $_.Length -lt 1000} | Sort-Object -Unique}
$r | ConvertTo-Json -Depth 5
