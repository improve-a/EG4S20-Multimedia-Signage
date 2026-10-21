$r='D:\FPGA\EG4S20-Bot-HDMIProbe'
New-Item -ItemType Directory -Force "$r\experiments" | Out-Null
git -C $r status --short
