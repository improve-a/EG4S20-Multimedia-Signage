$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
$files=@('ext\html_caption_column_rom.v','ext\html_layer_descriptor_rom.v','ext\html_layer_palette.v','ext\html_osd_overlay.v','ext\html_osd_swap_rom.v','ext\html_scene_motion.v')
foreach($f in $files){
 "##### $f"
 $la=Get-Content "$a\$f"; $lb=Get-Content "$b\$f"
 $d=Compare-Object $la $lb -IncludeEqual:$false
 $d | ForEach-Object { "{0} {1}" -f $_.SideIndicator, $_.InputObject }
}
