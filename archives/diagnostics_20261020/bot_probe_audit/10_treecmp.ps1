[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Stop'
$failRoot = 'D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design'
$passRoot = 'D:\FPGA\EG4S20-NoBot-HDMIProbe\output\html_fidelity\builds\hdmi_probe_001\work\design'
$failSrc = Join-Path $failRoot 'user_source\hdl_source'
$passSrc = Join-Path $passRoot 'user_source\hdl_source'

function Sha([string]$p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() }
function Norm([string]$p, [string]$root) {
  $t = [IO.File]::ReadAllText($p)
  $t = $t.Replace($root, '<ROOT>')
  $t = $t.Replace($root.Replace('\', '/'), '<ROOT>')
  $t.Replace("`r`n", "`n")
}

$fset = @{}; $pset = @{}
Get-ChildItem -LiteralPath $failSrc -Recurse -File | ForEach-Object { $fset[$_.FullName.Substring($failSrc.Length + 1)] = $_.FullName }
Get-ChildItem -LiteralPath $passSrc -Recurse -File | ForEach-Object { $pset[$_.FullName.Substring($passSrc.Length + 1)] = $_.FullName }
Write-Output ("files fail=" + $fset.Count + " pass=" + $pset.Count)
$onlyF = $fset.Keys | Where-Object { -not $pset.ContainsKey($_) } | Sort-Object
$onlyP = $pset.Keys | Where-Object { -not $fset.ContainsKey($_) } | Sort-Object
Write-Output ("ONLY_IN_FAIL: " + ($onlyF -join ', '))
Write-Output ("ONLY_IN_PASS: " + ($onlyP -join ', '))
$byteDiff = 0; $normDiff = 0
foreach ($k in ($fset.Keys | Where-Object { $pset.ContainsKey($_) } | Sort-Object)) {
  $a = $fset[$k]; $b = $pset[$k]
  $ha = Sha $a; $hb = Sha $b
  if ($ha -eq $hb) { continue }
  $byteDiff++
  $na = Norm $a $failRoot; $nb = Norm $b $passRoot
  if ($na -eq $nb) { Write-Output ("  PATH_OR_EOL_ONLY  $k") }
  else { $normDiff++; Write-Output ("  CONTENT_DIFF      $k  fail=$($ha.Substring(0,12)) pass=$($hb.Substring(0,12))") }
}
Write-Output ("common byte-differing files=" + $byteDiff + " content-differing=" + $normDiff)
Write-Output "=== hdl_source top/probe hashes ==="
Write-Output ("FAIL_TOP   " + (Sha (Join-Path $failSrc 'top_tf_hdmi_audio.v')))
Write-Output ("PASS_TOP   " + (Sha (Join-Path $passSrc 'top_tf_hdmi_audio.v')))
Write-Output ("PASS_PROBE " + (Sha (Join-Path $passSrc 'ext\hdmi_probe.v')))
Write-Output "=== DONE ==="
