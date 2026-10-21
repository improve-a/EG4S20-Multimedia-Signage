$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
foreach($p in @(@('NoBot','D:\FPGA\EG4S20-NoBot','6ee7c70'),@('Probe','D:\FPGA\EG4S20-NoBot-HDMIProbe','72e5c80e'))){
 "##### " + $p[0] + " HEAD=" + (& git -C $p[1] rev-parse HEAD)
 $files = & git -C $p[1] ls-tree -r $p[2] --name-only
 $files | Where-Object { $_ -match 'top_tf_hdmi_audio|video_rgb_to_axis|hdmi_probe\.v|hdmi_phy_warpper' }
}
