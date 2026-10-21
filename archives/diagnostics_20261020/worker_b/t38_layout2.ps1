$ErrorActionPreference='Stop'
foreach($p in @(@('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'),@('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt'))){
 $L=Get-Content $p[1]
 "##### $($p[0])"
 foreach($sig in @('HDMI_D0_P_syn_2.do[0]','HDMI_D1_P_syn_2.do[0]','HDMI_D2_P_syn_2.do[0]','HDMI_CLK_P_syn_2.do[0]')){
  $hit=$false
  for($i=0;$i -lt $L.Count;$i++){
   if(-not $hit -and $L[$i] -match [regex]::Escape($sig)){
    $hit=$true
    "--- $sig"
    $L[($i-5)..$i] | ForEach-Object { $_.TrimEnd() }
   }
  }
 }
}
