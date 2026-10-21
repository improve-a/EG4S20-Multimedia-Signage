[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
Write-Output "=== ENABLE_LAYER_RESOURCES / ENABLE_EXHIBIT in both tops ==="
foreach ($p in @('D:\FPGA\EG4S20-Multimedia-Signage\rtl\top_tf_hdmi_audio.v','D:\FPGA\EG4S20-NoBot-HDMIProbe\rtl\top_tf_hdmi_audio.v','D:\FPGA\EG4S20-Bot-HDMIProbe\rtl\top_tf_hdmi_audio.v')) {
  Write-Output ("--- " + $p)
  if (Test-Path $p) { Select-String -LiteralPath $p -Pattern 'ENABLE_LAYER_RESOURCES|ENABLE_EXHIBIT|html_scene_loader|resource_catalog_ready' | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() } } else { Write-Output MISSING }
}
Write-Output "=== NoBot observations/STATUS ==="
foreach ($f in @('D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\observations.json','D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\STATUS.json','D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\sram_01\stdout.log','D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_20261019T140608Z\sram_01\sram.tcl','D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_retest_20261019T152547Z\metadata.json','D:\FPGA\EG4S20-NoBot\output\hardware\no_bot_retest_20261019T152547Z\stdout.log')) {
  Write-Output ("===== " + $f); if (Test-Path $f) { Get-Content -LiteralPath $f -Raw -Encoding UTF8 } else { Write-Output MISSING }; Write-Output ''
}
Write-Output "=== tool version info ==="
foreach ($e in @('G:\anlu\bin\bw.exe','G:\anlu\bin\bw_commands_prompt.exe','G:\anlu\bin\alps.exe','G:\anlu\bin\td_commands_prompt.exe','G:\anlu\bin\svf2aje.exe')) {
  if (Test-Path $e) { $v=(Get-Item -LiteralPath $e).VersionInfo; "{0}  FileVersion={1}  Product={2}  Desc={3}" -f (Split-Path $e -Leaf), $v.FileVersion, $v.ProductName, $v.FileDescription }
}
Write-Output "=== DONE ==="
