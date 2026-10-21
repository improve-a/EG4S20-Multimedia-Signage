[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$r=[ordered]@{TimeUTC=(Get-Date).ToUniversalTime().ToString('o');ProcessId=$PID}
$r.BinFiles=@(Get-ChildItem 'G:\anlu\bin' -File | Select-Object Name,Length)
$r.DocFiles=@(Get-ChildItem 'G:\anlu\doc' -File -Recurse | Select-Object FullName,Length)
$r.Scripts=@(Get-ChildItem 'G:\anlu\cw','G:\anlu\lib','G:\anlu\bin','G:\anlu\driver' -Recurse -File -ErrorAction SilentlyContinue | Where-Object {$_.Extension -in '.tcl','.txt','.ini','.cfg','.bat','.cmd','.html'} | Select-String -Pattern 'cable|jtag|programmer|scan_chain' -List | Select-Object Path,LineNumber,Line)
$r.INFs=@(Get-ChildItem 'G:\anlu\driver' -Recurse -Filter '*.inf' | ForEach-Object {[pscustomobject]@{Path=$_.FullName;Content=(Get-Content $_.FullName -Raw)}})
$r.Catalogs=@(Get-ChildItem 'G:\anlu\driver' -Recurse -Filter '*.cat' | ForEach-Object {$s=Get-AuthenticodeSignature $_.FullName;[pscustomobject]@{Path=$_.FullName;Status=$s.Status.ToString();Signer=$s.SignerCertificate.Subject;TimestampSigner=$s.TimeStamperCertificate.Subject;SHA256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash}})
$r | ConvertTo-Json -Depth 8
