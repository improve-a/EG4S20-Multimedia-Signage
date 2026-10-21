$ErrorActionPreference='Stop'
$a='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source'
$b='D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design\user_source'
$fa=@{}; Get-ChildItem -Recurse -File $a | ForEach-Object { $r=$_.FullName.Substring($a.Length+1); $fa[$r]=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash }
$fb=@{}; Get-ChildItem -Recurse -File $b | ForEach-Object { $r=$_.FullName.Substring($b.Length+1); $fb[$r]=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash }
"ONLY_IN_FAIL:"; $fa.Keys | Where-Object {-not $fb.ContainsKey($_)} | Sort-Object
"ONLY_IN_PASS:"; $fb.Keys | Where-Object {-not $fa.ContainsKey($_)} | Sort-Object
"DIFFER:"; $fa.Keys | Where-Object {$fb.ContainsKey($_) -and $fb[$_] -ne $fa[$_]} | Sort-Object
"counts fail=$($fa.Count) pass=$($fb.Count)"
