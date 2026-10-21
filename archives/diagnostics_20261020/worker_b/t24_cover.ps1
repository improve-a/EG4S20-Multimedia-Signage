$ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
foreach($f in @('display_commit.v','ext\video_transition.v')){
 "##### $f"; Get-Content "$b\$f"
}
