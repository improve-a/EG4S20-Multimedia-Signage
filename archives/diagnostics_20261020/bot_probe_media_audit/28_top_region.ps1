[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$ErrorActionPreference = 'Continue'
$p='D:\FPGA\EG4S20-Multimedia-Signage\rtl\top_tf_hdmi_audio.v'
Get-Content -LiteralPath $p -Encoding UTF8 | Select-Object -Skip 194 -First 45 | ForEach-Object -Begin {$i=195} -Process { "{0,4}: {1}" -f $i, $_; $i++ }
Write-Output "=== bmp_read / sd_card_bmp pixel-offset checks (old repo) ==="
Select-String -LiteralPath 'D:\FPGA\EG4S20-Multimedia-Signage\rtl\SD\bmp_read.v' -Pattern 'offset|54|512|bfSize|file_size' | Select-Object -First 25 | ForEach-Object { "{0}: {1}" -f $_.LineNumber, $_.Line.Trim() }
Write-Output "=== DONE ==="
