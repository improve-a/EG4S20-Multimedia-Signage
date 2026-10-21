[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$r='D:\FPGA\EG4S20-Bot-HDMIProbe'
Write-Output "=== Bot scene loader params ==="
Select-String -LiteralPath "$r\rtl\ext\html_scene_loader.v" -Pattern 'SET_ID|BASE_WORDS|LENGTH_WORDS' | Select-Object -First 3 | ForEach-Object { $_.Line.Trim() }
Write-Output "=== hash compare with old repo (scene loader / locator / bmp_scale / sd_card_bmp) ==="
$pairs = @(
 @('rtl\ext\html_scene_loader.v','rtl\ext\html_scene_loader.v'),
 @('rtl\ext\html_resource_locator.v','rtl\ext\html_resource_locator.v'),
 @('rtl\ext\bmp_scale.v','rtl\ext\bmp_scale.v'),
 @('rtl\SD\sd_card_bmp.v','rtl\SD\sd_card_bmp.v'),
 @('rtl\ext\html_panel_loader.v','rtl\ext\html_panel_loader.v')
)
foreach ($p in $pairs) {
  $a = Join-Path 'D:\FPGA\EG4S20-Multimedia-Signage' $p[0]
  $b = Join-Path $r $p[1]
  $ha = if (Test-Path $a) { (Get-FileHash $a -Algorithm SHA256).Hash } else { 'MISSING' }
  $hb = if (Test-Path $b) { (Get-FileHash $b -Algorithm SHA256).Hash } else { 'MISSING' }
  "{0,-34} old={1}  bot={2}  {3}" -f $p[0], $ha.Substring(0,12), $hb.Substring(0,12), $(if($ha -eq $hb){'SAME'}else{'DIFF'})
}
Write-Output "=== does Bot top exist / flags? ==="
if (Test-Path "$r\rtl\top_tf_hdmi_audio.v") { Write-Output 'top present' } else { Write-Output 'top MISSING (mid-port)' }
Write-Output "=== DONE ==="
