$ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
Select-String -Path "$b\media_controls.v" -Pattern 'muted|volume|if\(rst\)|<=|reg ' | Select-Object -First 60 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
