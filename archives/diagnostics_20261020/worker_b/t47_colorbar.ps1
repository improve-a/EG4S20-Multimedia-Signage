$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z='D:\FPGA\EG4S20-NoBot-HDMIDiag\output\hdmi_colorbar_diag\delivery\hdmi_colorbar_diag_001_source.zip'
if(-not (Test-Path $z)){ "MISSING $z"; exit }
$h=(Get-FileHash -Algorithm SHA256 $z).Hash.ToLower(); $len=(Get-Item $z).Length
"zip=$len bytes sha256=$h"
$a=[IO.Compression.ZipFile]::OpenRead($z)
try{
 $e=$a.Entries | Where-Object { $_.FullName -match 'top_tf_hdmi_audio\.v$' } | Select-Object -First 1
 "entry=" + $e.FullName + " size=" + $e.Length
 $sr=New-Object IO.StreamReader($e.Open())
 $t=$sr.ReadToEnd(); $sr.Close()
 $lines=$t -split "`r?`n"
 for($i=0;$i -lt $lines.Count;$i++){
  if($lines[$i] -match 'video_rgb_to_axis|html_video_overlay|vout_data|display_valid|fx_rgb|fx_de|fx_vs|colorbar|I_rgb'){
   "{0}: {1}" -f ($i+1),$lines[$i].TrimEnd()
  }
 }
} finally { $a.Dispose() }
