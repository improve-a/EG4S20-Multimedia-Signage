$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$root = 'D:\FPGA\EG4S20-NoBot-RCA-20261020'
$d = "$root\delivery"
$expected = @{
  'rca_no_locked_003.bit'  = 'cce449034505c4d5c61a856b94b48c4c3d7e20a3eb86627972763a1981ca46a5'
  'rca_locked_only_001.bit' = '41848d2090bc22695be98f096167005c4aceaecffbd6d20ecb0dc5b7440dba4a'
}

Write-Output '=== EXACT BITSTREAM FILES ==='
foreach ($name in $expected.Keys | Sort-Object) {
  $p = Join-Path $d $name
  if (!(Test-Path $p)) { throw "Missing bitstream: $p" }
  $f = Get-Item $p
  $h = (Get-FileHash -Algorithm SHA256 $p).Hash.ToLower()
  if ($h -ne $expected[$name]) { throw "Bitstream hash mismatch: $name" }
  if ($f.Length -ne 677348) { throw "Unexpected bitstream size: $name $($f.Length)" }
  Write-Output ("MATCH {0}  bytes={1}  sha256={2}`n      {3}" -f $name,$f.Length,$h,$f.FullName)
}

Write-Output '=== DELIVERY SHA256SUMS ==='
$count = 0
Get-Content (Join-Path $d 'SHA256SUMS.txt') | ForEach-Object {
  if ($_ -match '^([a-f0-9]{64})  (.+)$') {
    $exp = $matches[1]; $name = $matches[2]
    $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $d $name)).Hash.ToLower()
    if ($actual -ne $exp) { throw "Delivery hash mismatch: $name" }
    $count++
  }
}
Write-Output "PASS: $count delivery hashes verified"

Write-Output '=== BUILD MANIFESTS ==='
foreach ($id in @('rca_no_locked_003','rca_locked_only_001')) {
  $m = Get-Content "$d\${id}_manifest.json" -Encoding UTF8 | ConvertFrom-Json
  $s = Get-Content "$root\builds\$id\runs\$id\status.json" -Encoding UTF8 | ConvertFrom-Json
  if ($m.run_id -ne $id) { throw "Manifest run_id mismatch: $id" }
  if (!$m.BUILD_PASS) { throw "BUILD_PASS false: $id" }
  if ($m.bit.path -ne "$d\$id.bit") { throw "Manifest bit path mismatch: $id" }
  if ($m.bit.sha256 -ne $expected["$id.bit"]) { throw "Manifest bit hash mismatch: $id" }
  if ($s.state -ne 'FINISHED' -or $s.exit_code -ne 0 -or !$s.flow_complete) { throw "Build status not complete: $id" }
  $area = Get-Content "$root\builds\$id\runs\$id\final_area.rpt"
  $dev = ($area | Select-String -Pattern '^\*{3}Report Model:.*Device:\s+(\S+)\*{3}$').Matches.Groups[1].Value
  if ($dev -ne 'EG4S20BG256') { throw "Device mismatch in final_area: $id $dev" }
  Write-Output ("{0}: BUILD_PASS={1}  FINISHED exit=0  commit={2}  setup={3}ns hold={4}ns  LUT={5} REG={6}  device={7}" -f `
    $id,$m.BUILD_PASS,$m.source_commit,$m.timing.setup.wns_ns,$m.timing.hold.wns_ns,$m.resources.LUT.used,$m.resources.FF.used,$dev)
  Write-Output ("  source_zip={0}  reports_zip={1}" -f $m.source_zip.sha256,$m.report_zip.sha256)
  Write-Output ("  source_hash={0}" -f (Get-FileHash -Algorithm SHA256 "$d\${id}_source.zip").Hash.ToLower())
}

Write-Output '=== CABLE / DEVICE ID (READ ONLY) ==='
$script = @'
list_cable
set rc [catch {read_device_id -cable 0} result]
puts "P0_PRE_ID_RC=$rc RESULT=$result"
exit
'@
$out = $script | & 'G:\anlu\bin\td_commands_prompt.exe' 2>&1
$out | ForEach-Object { "$_" }
$joined = ($out -join "`n")
if ($joined -match 'P0_PRE_ID_RC=0 RESULT=EG4S20BG256') {
  Write-Output 'P0_DEVICE_ID_PASS'
} else {
  throw 'P0 JTAG device ID not confirmed'
}
