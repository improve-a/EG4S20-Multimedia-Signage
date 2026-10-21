$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
Get-ChildItem G:\anlu | Select-Object Mode,Name | Format-Table -AutoSize | Out-String -Width 120
"--- bin"
Get-ChildItem G:\anlu\bin -File | Select-Object Name,Length | Format-Table -AutoSize | Out-String -Width 120
"--- doc dirs"
Get-ChildItem G:\anlu -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object FullName | Out-String -Width 200
