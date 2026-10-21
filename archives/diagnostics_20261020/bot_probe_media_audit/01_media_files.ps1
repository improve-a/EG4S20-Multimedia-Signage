[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$roots = @{
  OLD  = 'D:\FPGA\EG4S20-Multimedia-Signage'
  NOB  = 'D:\FPGA\EG4S20-NoBot-HDMIProbe'
  BOT  = 'D:\FPGA\EG4S20-Bot-HDMIProbe'
}
$exts = @('.hfxl','.bin','.bmp','.wav','.raw','.dat','.img','.mp3','.jpg','.jpeg','.png','.ico','.hfx','.rom','.mif','.hex','.coe')
foreach ($k in @('OLD','NOB','BOT')) {
  Write-Output ("=== $k " + $roots[$k] + " ===")
  $r = $roots[$k]
  if (-not (Test-Path $r)) { Write-Output "MISSING"; continue }
  $f = Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
       Where-Object { $exts -contains $_.Extension.ToLower() }
  Write-Output ("count=" + $f.Count)
  $f | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($r.Length).TrimStart('\')
    "{0,10}  {1}  {2}" -f $_.Length, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $rel
  }
}
Write-Output "=== DONE ==="
