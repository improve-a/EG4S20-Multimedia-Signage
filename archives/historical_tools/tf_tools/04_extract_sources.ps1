$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false)
$env:PYTHONIOENCODING='utf-8'
python 'D:\FPGA\hx4s20_tf_test_20261013\04_extract_sources.py'
exit $LASTEXITCODE
