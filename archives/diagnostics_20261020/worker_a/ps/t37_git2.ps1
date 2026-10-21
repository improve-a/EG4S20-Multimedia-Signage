$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
$r='D:\FPGA\EG4S20-NoBot'
& git -C $r ls-tree -r 6ee7c70 --name-only | Where-Object { $_ -match '^rtl/.*\.v$' }
"### all top-ish"
& git -C $r ls-tree -r 6ee7c70 --name-only | Where-Object { $_ -match 'top' }
