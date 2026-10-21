[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ProgressPreference='SilentlyContinue'
Get-ChildItem 'G:\anlu\doc' -File -Recurse | Select-Object FullName,Length | ConvertTo-Json
Get-Content 'G:\anlu\driver\dl-cable\win10\cyusb.inf'
Get-ChildItem 'G:\anlu\bin' -File | Select-Object Name,Length | ConvertTo-Json
