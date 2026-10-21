$ErrorActionPreference='Stop'
foreach($p in @(@('FAIL','D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\runs\no_bot_legacy_004\final_timing.rpt'),@('PASS','D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\runs\hdmi_probe_001\final_timing.rpt'))){
 $L=Get-Content $p[1]
 "##### $($p[0]) ODDR / output reg lines"
 for($i=0;$i -lt $L.Count;$i++){
  if($L[$i] -match '^(ODDR|clk2q)\s+.*pin: (HDMI_|.*S_oddr_data_reg)'){
   $loc=($L[$i] -split '\s+')[2]
   $pin=($L[$i] -split 'pin: ')[1]
   "{0}  {1}  L{2}" -f $loc,$pin,$i
  }
 }
}
