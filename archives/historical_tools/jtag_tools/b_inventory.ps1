[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$base='G:\macshare\嵌赛\HX4S20_Contest_202606'
Get-ChildItem -LiteralPath (Join-Path $base '1_安路开发工具和常用软件') -Recurse -File | Select FullName,Length | ConvertTo-Json -Depth 3
'BOARD DOCS'
Get-ChildItem -LiteralPath $base -Recurse -File | Where-Object {$_.Extension -in '.pdf','.docx','.inf','.chm' -and $_.FullName -notmatch 'lab|Lab|仿真|示例|实验'} | Select FullName,Length | ConvertTo-Json -Depth 3
'ARCHIVE TOOLS'
Get-Command 7z,tar,python -ErrorAction SilentlyContinue | Select Name,Source | ConvertTo-Json
