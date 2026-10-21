$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$aPath = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_001_source.zip'
$bPath = 'D:\FPGA\EG4S20-Bot-HDMIProbe\artifacts\bot_hdmi_probe_infer_add_off_001_source.zip'
$jobs = @(
    @{ Zip = $aPath; Name = 'work/design/td_project/hx4s20_basic.al'; Tag = 'A_AL' },
    @{ Zip = $bPath; Name = 'work/design/td_project/hx4s20_basic.al'; Tag = 'B_AL' },
    @{ Zip = $aPath; Name = 'audit/baseline_manifest.json'; Tag = 'A_MANIFEST' },
    @{ Zip = $bPath; Name = 'audit/baseline_manifest.json'; Tag = 'B_MANIFEST' },
    @{ Zip = $bPath; Name = 'audit/infer_add_only.diff'; Tag = 'B_INFER_DIFF' },
    @{ Zip = $bPath; Name = 'audit/infer_add_audit.json'; Tag = 'B_INFER_AUDIT' },
    @{ Zip = $bPath; Name = 'audit/scope.json'; Tag = 'B_SCOPE' },
    @{ Zip = $bPath; Name = 'audit/bot_probe_audit.json'; Tag = 'B_BOT_AUDIT' },
    @{ Zip = $bPath; Name = 'harness/build.tcl'; Tag = 'B_BUILD_TCL' },
    @{ Zip = $bPath; Name = 'work/design/user_source/hdl_source/ext/hdmi_probe.v'; Tag = 'B_PROBE' },
    @{ Zip = $bPath; Name = 'work/design/user_source/hdl_source/IP/sys_pll.v'; Tag = 'B_SYS_PLL' },
    @{ Zip = $bPath; Name = 'work/design/user_source/hdl_source/IP/video_pll.v'; Tag = 'B_VIDEO_PLL' },
    @{ Zip = $bPath; Name = 'work/design/td_project/al_ip/PLL.v'; Tag = 'B_AL_PLL' },
    @{ Zip = $bPath; Name = 'work/design/td_project/al_ip/PLL.ipc'; Tag = 'B_AL_PLL_IPC' },
    @{ Zip = $bPath; Name = 'work/design/td_project/al_ip/PLL.vhd'; Tag = 'B_AL_PLL_VHD' }
)
$cache = @{}
foreach ($job in $jobs) {
    $zipPath = $job.Zip
    if (-not $cache.ContainsKey($zipPath)) { $cache[$zipPath] = [System.IO.Compression.ZipFile]::OpenRead($zipPath) }
    $z = $cache[$zipPath]
    $e = $z.GetEntry($job.Name)
    if ($null -eq $e) {
        Write-Output ('MISSING ' + $job.Tag + ' ' + $job.Name)
        continue
    }
    $s = $e.Open()
    try {
        $ms = New-Object System.IO.MemoryStream
        $s.CopyTo($ms)
        $b64 = [Convert]::ToBase64String($ms.ToArray())
    } finally { $s.Dispose() }
    Write-Output ('B64 ' + $job.Tag + ' ' + $job.Name + ' ' + $b64)
}
foreach ($z in $cache.Values) { $z.Dispose() }
