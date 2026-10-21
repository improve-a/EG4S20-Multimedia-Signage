$ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
"##### audio_output_mux"
Get-Content "$b\ext\audio_output_mux.v"
"##### audio_media wav_selected/status"
Select-String -Path "$b\ext\audio_media.v" -Pattern 'wav_selected|status|enable|sd_ready|assign' | Select-Object -First 40 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
