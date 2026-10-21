$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
Get-ChildItem G:\anlu\doc -Recurse -File | Select-Object Length,FullName | Format-Table -AutoSize | Out-String -Width 250
