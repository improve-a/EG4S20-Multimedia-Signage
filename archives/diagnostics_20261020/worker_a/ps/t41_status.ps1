$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
foreach($r in @('D:\FPGA\EG4S20-NoBot','D:\FPGA\EG4S20-NoBot-HDMIProbe')){
 "##### $r"
 $s = & git -C $r status --porcelain
 "changed_entries=" + @($s).Count
 $s | Select-Object -First 15
}
