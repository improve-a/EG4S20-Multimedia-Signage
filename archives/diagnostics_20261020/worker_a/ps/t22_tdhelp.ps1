$ProgressPreference='SilentlyContinue'; $ErrorActionPreference='Stop'
Set-Location 'D:\FPGA\EG4S20-NoBot-RCA-20261020\worker_a'
& 'G:\anlu\bin\td_commands_prompt.exe' -h 2>&1 | Select-Object -First 40
"exit=$LASTEXITCODE"
