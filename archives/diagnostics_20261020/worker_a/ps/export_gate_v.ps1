param(
    [string]$Db  = 'D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a\a_gate.db',
    [string]$Out = 'D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a\a_gate.v'
)
# Read-only export of a TD mapped DB to flattened gate-level Verilog.
# Runs ONLY: import_device / import_db / write_verilog. No optimize/place/route/bitgen.
# Always point -Db at a COPY in the scratch directory, never at a build output in place.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$OutDir = Split-Path -Parent $Out
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$DbF  = $Db  -replace '\\', '/'
$OutF = $Out -replace '\\', '/'
$Tcl  = @"
import_device eagle_s20.db -package EG4S20BG256
import_db {$DbF}
write_verilog {$OutF} -nobuf
exit
"@
$TclPath = Join-Path $OutDir 'export_one.tcl'
Set-Content -Path $TclPath -Value $Tcl -Encoding ascii
Set-Location $OutDir
& 'G:\anlu\bin\td_commands_prompt.exe' $TclPath
if (-not (Test-Path $Out)) { throw "export failed: $Out" }
"OK $Out " + (Get-Item $Out).Length
