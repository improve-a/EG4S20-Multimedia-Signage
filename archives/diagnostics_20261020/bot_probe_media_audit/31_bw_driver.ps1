[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== bw_commands_prompt reference in scripts (all repos, incl output) ==="
foreach ($r in @('D:\FPGA\EG4S20-Multimedia-Signage','D:\FPGA\EG4S20-NoBot')) {
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue -Include '*.py','*.ps1','*.md' |
    Where-Object { $_.Length -lt 300000 } |
    Select-String -Pattern 'bw_commands_prompt' -ErrorAction SilentlyContinue |
    Select-Object -First 12 | ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Substring($r.Length+1), $_.LineNumber, $_.Line.Trim() }
}
Write-Output "=== tool identity ==="
foreach ($e in @('G:\anlu\bin\bw.exe','G:\anlu\bin\bw_commands_prompt.exe','G:\anlu\bin\alps.exe','G:\anlu\bin\svf2aje.exe','G:\anlu\bin\hwserver.exe')) {
  if (Test-Path $e) {
    $v=(Get-Item -LiteralPath $e).VersionInfo
    "{0,-28} {1,10} sha={2} ver={3} desc={4}" -f (Split-Path $e -Leaf), (Get-Item $e).Length, (Get-FileHash $e -Algorithm SHA256).Hash.Substring(0,16), $v.FileVersion, $v.FileDescription
  } else { Write-Output ("MISSING " + $e) }
}
Write-Output "=== DONE ==="
