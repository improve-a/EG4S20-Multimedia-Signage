$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$root='D:\FPGA\hx4s20_tf_test_20261013'
if(Test-Path "$root\card_before_hashes.json") {throw 'Baseline already exists; do not overwrite'}
$rows=@(Get-ChildItem 'K:\' -Recurse -Force -File | ForEach-Object {
 $f=$_;try {$hash=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash;[ordered]@{path=$f.FullName;size=$f.Length;sha256=$hash;error=$null}}catch{[ordered]@{path=$f.FullName;size=$f.Length;sha256=$null;error=$_.Exception.Message}}
})
$rows|ConvertTo-Json -Depth 4|Set-Content "$root\card_before_hashes.json" -Encoding utf8
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');pid=$PID;files=$rows.Count;bytes=($rows|Measure-Object size -Sum).Sum;hash_failures=@($rows|Where-Object {$_.error});evidence="$root\card_before_hashes.json"}|ConvertTo-Json -Depth 5
