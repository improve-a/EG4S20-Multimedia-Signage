$ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
foreach($f in @('video_clocks.v','system_clocks.v','reset_sync.v','hdmi_phy_warpper.v','lane_lvds_10_1.v','video_rgb_to_axis_640x480.v')){
 "##### $f"; Get-Content "$b\$f"
}
