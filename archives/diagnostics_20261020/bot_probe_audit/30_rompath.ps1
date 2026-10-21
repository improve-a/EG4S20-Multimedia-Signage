[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$f = 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design'
$p = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design'
$names = @('html_caption_column_rom.v','html_layer_descriptor_rom.v','html_layer_palette.v','html_osd_overlay.v','html_osd_swap_rom.v','html_scene_motion.v')
foreach ($n in $names) {
  $fa = Join-Path $f ('user_source\hdl_source\ext\' + $n)
  $pa = Join-Path $p ('user_source\hdl_source\ext\' + $n)
  $ft = [IO.File]::ReadAllText($fa).Replace($f, '<R>').Replace($f.Replace('\','/'), '<R>')
  $pt = [IO.File]::ReadAllText($pa).Replace($p, '<R>').Replace($p.Replace('\','/'), '<R>')
  $same = $ft -ceq $pt
  Write-Output ("{0,-32} path-only-equal={1} failCRLF={2} passCRLF={3}" -f $n, $same, ([regex]::Matches($ft,"`r`n")).Count, ([regex]::Matches($pt,"`r`n")).Count)
}
