$b='D:\FPGA\EG4S20-NoBot-RCA-20261020\builds\rca_no_locked_002'
Get-Content "$b\audit\dispatch.log"
if(Test-Path "$b\runs\rca_no_locked_002\status.json") {Get-Content "$b\runs\rca_no_locked_002\status.json"}
if(Test-Path "$b\runs\rca_no_locked_002\stages.tsv") {Get-Content "$b\runs\rca_no_locked_002\stages.tsv"}
Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'td_commands_prompt|td.exe|fdp|python.exe'} | Select-Object ProcessId,ParentProcessId,Name,CommandLine | Format-List
