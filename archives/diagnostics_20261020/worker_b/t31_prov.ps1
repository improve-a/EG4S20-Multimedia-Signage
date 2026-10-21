$ErrorActionPreference='Stop'
$sets=@(
 @('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'),
 @('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'))
foreach($p in $sets){
 $t=$p[0];$d=$p[1]
 $rid=if($t -eq 'FAIL'){'no_bot_legacy_004'}else{'hdmi_probe_001'}
 "##### $t"
 foreach($f in @("runs\$rid\final_timing.rpt","runs\$rid\after_hold_fix.rpt","runs\$rid\before_hold_fix.rpt","work\design\td_project\hx4s20_basic_Runs\phy_1\final_timing.rpt","work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic_pr.timing","work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic.bit","work\design\td_project\hx4s20_basic_Runs\phy_1\hx4s20_basic_pr.db")){
  $path=Join-Path $d $f
  if(Test-Path $path){ $i=Get-Item $path; "{0,10} {1} {2}" -f $i.Length,$i.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'),$f } else { "MISSING $f" }
 }
}
