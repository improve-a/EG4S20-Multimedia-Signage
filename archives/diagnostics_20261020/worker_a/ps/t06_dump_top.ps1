$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$r='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
Get-Content "$r\top_tf_hdmi_audio.v" | ForEach-Object -Begin {$i=0} -Process { $i++; "{0,4}: {1}" -f $i,$_ }
