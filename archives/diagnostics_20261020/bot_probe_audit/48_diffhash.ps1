[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead('D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip')
$e = $z.GetEntry('audit/probe_only.diff'); $ms = New-Object IO.MemoryStream; $s = $e.Open(); $s.CopyTo($ms); $s.Close(); $z.Dispose()
$b = $ms.ToArray()
$n = [Text.Encoding]::UTF8.GetBytes(([Text.Encoding]::UTF8.GetString($b)).Replace("`r`n", "`n"))
Write-Output ("zip raw  sha256 " + [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($b)).Replace('-','').ToLower() + " len=" + $b.Length)
Write-Output ("zip norm sha256 " + [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($n)).Replace('-','').ToLower() + " len=" + $n.Length)
Write-Output ("zip CR count " + ([regex]::Matches([Text.Encoding]::UTF8.GetString($b), "`r")).Count)
