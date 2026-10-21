$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
python 'D:\FPGA\hx4s20_usb_jtag_harness_20261013\root_bw_help.py'
exit $LASTEXITCODE
