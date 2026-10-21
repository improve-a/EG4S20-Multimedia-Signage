[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== uninstall entries (Anlogic/TD) ==="
foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
  Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Anlogic|TD|Tang' } |
    Select-Object DisplayName,DisplayVersion,InstallLocation | Format-Table -AutoSize | Out-String -Width 200
}
Write-Output "=== start menu shortcuts ==="
Get-ChildItem -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs','C:\Users\52760\AppData\Roaming\Microsoft\Windows\Start Menu\Programs' -Recurse -File -Filter '*.lnk' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'TD|Anlogic|Programmer|Tang' } | ForEach-Object { $_.FullName }
Write-Output "=== WScript shell target resolve ==="
$sh = New-Object -ComObject WScript.Shell
Get-ChildItem -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs','C:\Users\52760\AppData\Roaming\Microsoft\Windows\Start Menu\Programs' -Recurse -File -Filter '*.lnk' -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'TD|Anlogic|Programmer|Tang' } | ForEach-Object {
    $l = $sh.CreateShortcut($_.FullName)
    "{0} -> {1}  [args: {2}] [workdir: {3}]" -f $_.Name, $l.TargetPath, $l.Arguments, $l.WorkingDirectory
  }
Write-Output "=== td.exe anywhere on D: (top depth 5) ==="
Get-ChildItem -LiteralPath 'D:\' -Recurse -File -Include 'td.exe','td_programmer.exe','Programmer.exe' -ErrorAction SilentlyContinue -Depth 5 |
  ForEach-Object { "{0,10} {1} {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd'), $_.FullName }
Write-Output "=== DONE ==="
