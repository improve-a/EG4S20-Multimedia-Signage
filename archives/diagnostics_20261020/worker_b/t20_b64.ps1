$ErrorActionPreference='Stop'
$pairs=@(
 @('fail','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'),
 @('pass','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'))
$files=@('top_tf_hdmi_audio.v','ext\html_caption_column_rom.v','ext\html_layer_descriptor_rom.v','ext\html_layer_palette.v','ext\html_osd_overlay.v','ext\html_osd_swap_rom.v','ext\html_scene_motion.v')
foreach($p in $pairs){ foreach($f in $files){ $path=Join-Path $p[1] $f; if(Test-Path $path){ "===B64 $($p[0])/$f"; [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) } } }
