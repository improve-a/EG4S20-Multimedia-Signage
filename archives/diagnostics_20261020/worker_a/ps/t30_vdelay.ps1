$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source\SD\video_delay.v'
Get-Content $a | ForEach-Object -Begin {$i=0} -Process { $i++; "{0,4}: {1}" -f $i,$_ }
