[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$dirs = @(
 'D:\FPGA\EG4S20-Multimedia-Signage\output\hardware\hw_20261016T095019Z\card_backup',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_emergency_ui\tf_card_package',
 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\venue_unified_offline\media'
)
foreach ($d in $dirs) {
  Write-Output ("=== DIR " + $d + " ===")
  if (Test-Path $d) {
    Get-ChildItem -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue |
      ForEach-Object {
        $t = if ($_.PSIsContainer) { 'DIR ' } else { 'FILE' }
        $sz = if ($_.PSIsContainer) { '' } else { $_.Length }
        "{0} {1,10}  {2}  {3}" -f $t, $sz, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $_.FullName.Substring($d.Length).TrimStart('\')
      }
  } else { Write-Output "MISSING" }
}
Write-Output "=== DONE ==="
