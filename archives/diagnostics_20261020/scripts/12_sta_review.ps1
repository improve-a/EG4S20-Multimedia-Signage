$r='D:\FPGA\EG4S20-NoBot-RCA-20261020'
foreach($id in @('rca_no_locked_003','rca_locked_only_001')) {
 $d="$r\builds\$id\runs\$id"
 if(!(Test-Path "$d\final_timing.rpt")){continue}
 Write-Output "=== $id ==="
 Get-Content "$d\stages.tsv"
 Get-Content "$d\final_timing.rpt" -TotalCount 105
 Select-String -Path "$d\check_timing.rpt" -Pattern '^\d+\. checking' | ForEach-Object {$_.Line}
 Get-Content "$d\final_area.rpt" -TotalCount 65
 Select-String -Path "$d\stdout.log","$d\stderr.log" -Pattern 'ERROR|CRITICAL' | ForEach-Object {$_.Line}
}
