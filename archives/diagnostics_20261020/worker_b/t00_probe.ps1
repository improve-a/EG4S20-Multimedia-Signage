$ErrorActionPreference='Stop'
$b1='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004'
$b2='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001'
foreach($b in @($b1,$b2)){
 "===== $b"
 Get-ChildItem -Recurse -File $b -Include *.rpt,*.json,*.tsv,*.log,*.txt,*.rpt.gz -ErrorAction SilentlyContinue |
   Where-Object { $_.Length -lt 3000000 } |
   Sort-Object FullName |
   ForEach-Object { "{0,10} {1}" -f $_.Length, $_.FullName.Substring($b.Length+1) }
}
