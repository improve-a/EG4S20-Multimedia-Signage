$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$A='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'
$B='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
$files=@(
 @('A_runs_final',"$A\runs\no_bot_legacy_004\final_timing.rpt"),
 @('A_after_hold',"$A\runs\no_bot_legacy_004\after_hold_fix.rpt"),
 @('A_before_hold',"$A\runs\no_bot_legacy_004\before_hold_fix.rpt"),
 @('A_phy1_final',"$A\work\design\td_project\hx4s20_basic_Runs\phy_1\final_timing.rpt"),
 @('B_runs_final',"$B\runs\hdmi_probe_001\final_timing.rpt"),
 @('B_after_hold',"$B\runs\hdmi_probe_001\after_hold_fix.rpt"),
 @('B_phy1_final',"$B\work\design\td_project\hx4s20_basic_Runs\phy_1\final_timing.rpt")
)
foreach($f in $files){
 "##### " + $f[0]
 "sha=" + (Get-FileHash $f[1] -Algorithm SHA256).Hash
 (Get-Content $f[1] -TotalCount 45) | Select-String -Pattern 'Confidence|Generated|SWNS|HWNS|STA coverage|Constraint File' | ForEach-Object { $_.Line.Trim() }
}
