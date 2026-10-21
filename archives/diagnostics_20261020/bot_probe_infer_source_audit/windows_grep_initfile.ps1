$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_infer_add_off_001_source.zip'
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    foreach ($e in $zip.Entries) {
        if ($e.FullName.EndsWith('/')) { continue }
        $s = $e.Open()
        try {
            $sr = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::UTF8, $true)
            $text = $sr.ReadToEnd()
        } finally { $s.Dispose() }
        $lines = $text -split "`r?`n"
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match 'INIT_FILE|init_file|bot_hdmi_probe_001') {
                Write-Output ($e.FullName + ':' + ($i + 1) + ':' + $lines[$i].Trim())
            }
        }
    }
} finally { $zip.Dispose() }
