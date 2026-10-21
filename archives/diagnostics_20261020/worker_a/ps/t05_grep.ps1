$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$b=@{
 'A_nobot'='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
 'B_probe'='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source\hdl_source'
}
foreach($k in $b.Keys){
 "##### $k  root=" + $b[$k]
 $root=$b[$k]
 Get-ChildItem -Recurse -File $root -Include *.v,*.sv | ForEach-Object {
   $f=$_
   Select-String -Path $f.FullName -Pattern 'O_video_locked|tlast|tready|tvalid|tuser|tdata|video_locked|rs_video|button_reset50' -CaseSensitive:$false -ErrorAction SilentlyContinue |
     ForEach-Object { "{0}:{1}: {2}" -f ($f.FullName.Substring($root.Length+1)), $_.LineNumber, $_.Line.Trim() }
 }
}
