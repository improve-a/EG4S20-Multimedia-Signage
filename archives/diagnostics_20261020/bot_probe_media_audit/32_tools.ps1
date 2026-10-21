[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
foreach ($n in @('bw.exe','bw_commands_prompt.exe','alps.exe','svf2aje.exe','hwserver.exe','td_commands_prompt.exe')) {
  $e = Join-Path 'G:\anlu\bin' $n
  if (Test-Path $e) {
    $i = Get-Item -LiteralPath $e
    $h = (Get-FileHash -LiteralPath $e -Algorithm SHA256).Hash
    "{0,-26} {1,10}  ver={2,-16} desc={3}`n    sha256={4}" -f $n, $i.Length, $i.VersionInfo.FileVersion, $i.VersionInfo.FileDescription, $h
  } else { "MISSING $n" }
}
Write-Output "=== DONE ==="
