Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach($p in @('D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip','D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_infer_add_off_001_source.zip')){
  $z=[System.IO.Compression.ZipFile]::OpenRead($p)
  $names=$z.Entries | ForEach-Object { $_.FullName }
  $dups=$names | Group-Object | Where-Object { $_.Count -gt 1 }
  Write-Output ($p + '|entries=' + $names.Count + '|dups=' + ($dups.Count))
  foreach($d in $dups){ Write-Output ('  DUP ' + $d.Name + ' x' + $d.Count) }
  $z.Dispose()
}
