$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$env:PYTHONIOENCODING='utf-8'
python 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_verify_local_alternatives.py'
exit $LASTEXITCODE
