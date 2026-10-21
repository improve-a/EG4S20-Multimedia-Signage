$ErrorActionPreference='Stop'
$b='D:\FPGA\EG4S20-NoBot\output\html_fidelity\builds\no_bot_legacy_004\work\design\user_source\hdl_source'
"##### sd_card_top ports/clock"
Select-String -Path "$b\SD\sd_card_top.v" -Pattern 'module|clk|MISO|miso|SD_|assign|always' | Select-Object -First 50 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
"##### sec_read_write miso use"
Select-String -Path "$b\SD\sd_card_sec_read_write.v" -Pattern 'MISO|miso|posedge|negedge|clk' | Select-Object -First 40 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
"##### spi_master"
Select-String -Path "$b\SD\spi_master.v" -Pattern 'MISO|miso|posedge|negedge|clk|div' | Select-Object -First 40 | ForEach-Object { "{0}: {1}" -f $_.LineNumber,$_.Line.Trim() }
