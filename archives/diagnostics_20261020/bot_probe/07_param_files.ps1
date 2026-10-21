Get-ChildItem G:\anlu\bin -File | Where-Object {$_.Extension -in '.xml','.tcl','.cfg','.ini'} | Select-Object FullName
Get-ChildItem G:\anlu\lib,G:\anlu\template -Recurse -File | Where-Object {$_.Extension -in '.xml','.tcl','.cfg','.ini','.txt'} | Select-String -Pattern 'infer_add' | Select-Object -First 35 Path,LineNumber,Line
Get-Content D:\FPGA\EG4S20-Bot-HDMIProbe\harness\windows_job.py -Encoding UTF8 | Select-String 'td|cmd|Tcl' -Context 1,1
