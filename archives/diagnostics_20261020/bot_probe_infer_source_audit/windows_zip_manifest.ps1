$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-ZipManifest([string]$path) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $map = [ordered]@{}
        foreach ($e in $zip.Entries) {
            if ($e.FullName.EndsWith('/')) { continue }
            $s = $e.Open()
            try {
                $h = [System.BitConverter]::ToString($sha.ComputeHash($s)).Replace('-', '').ToLowerInvariant()
            } finally { $s.Dispose() }
            $map[$e.FullName] = [pscustomobject]@{ Length = $e.Length; Hash = $h }
        }
        $sha.Dispose()
        return $map
    } finally { $zip.Dispose() }
}

$aPath = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$bPath = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_infer_add_off_001_source.zip'
$a = Get-ZipManifest $aPath
$b = Get-ZipManifest $bPath

Write-Output ("ZIP_A=" + $aPath)
Write-Output ("ZIP_B=" + $bPath)
Write-Output ("COUNT_A=" + $a.Count)
Write-Output ("COUNT_B=" + $b.Count)
Write-Output 'MANIFEST_A_BEGIN'
foreach ($k in $a.Keys) { Write-Output ($k + '|' + $a[$k].Length + '|' + $a[$k].Hash) }
Write-Output 'MANIFEST_A_END'
Write-Output 'MANIFEST_B_BEGIN'
foreach ($k in $b.Keys) { Write-Output ($k + '|' + $b[$k].Length + '|' + $b[$k].Hash) }
Write-Output 'MANIFEST_B_END'

Write-Output 'ONLY_IN_A_BEGIN'
foreach ($k in $a.Keys) { if (-not $b.Contains($k)) { Write-Output $k } }
Write-Output 'ONLY_IN_A_END'
Write-Output 'ONLY_IN_B_BEGIN'
foreach ($k in $b.Keys) { if (-not $a.Contains($k)) { Write-Output $k } }
Write-Output 'ONLY_IN_B_END'
Write-Output 'DIFFERING_BEGIN'
foreach ($k in $a.Keys) {
    if ($b.Contains($k)) {
        if ($a[$k].Hash -ne $b[$k].Hash) {
            Write-Output ($k + '|A=' + $a[$k].Length + ':' + $a[$k].Hash + '|B=' + $b[$k].Length + ':' + $b[$k].Hash)
        }
    }
}
Write-Output 'DIFFERING_END'
Write-Output 'IDENTICAL_COUNT_BEGIN'
$same = 0
foreach ($k in $a.Keys) { if ($b.Contains($k) -and $a[$k].Hash -eq $b[$k].Hash) { $same++ } }
Write-Output $same
Write-Output 'IDENTICAL_COUNT_END'
