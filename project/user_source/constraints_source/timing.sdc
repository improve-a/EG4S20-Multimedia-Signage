# HX4S20C: input50, SD100, memory40/40 shifted180deg, video25/serial125MHz.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
rename_clock -name {sd_card_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {video_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]
# Pixel and serializer clocks operate concurrently. No exclusive clock group.
# FIFO constraints are imported by the original native IP project entries.
# Additional CDC and external IO constraints require endpoint/budget evidence.

# Actual RTL SPI_HIGH_SPEED_DIV=2: one SCLK half-cycle is4 sys100 cycles.
# SD default mode: tOD<=14ns; tSU/tH>=5ns. PCB envelope0..1ns per line.
# Scope, CE proof and edge audit: reports/io_timing_review.md + spi_io TB.
create_generated_clock -name sd_spi_clk -source [get_pins {sys_pll_m0/pll_inst.clkc[0]}] -master_clock {sd_card_clk} -divide_by 8 [get_ports {sd_dclk}]
set_input_delay -clock [get_clocks {sd_spi_clk}] -clock_fall -max 16.000 [get_ports {sd_miso}]
set_input_delay -clock [get_clocks {sd_spi_clk}] -clock_fall -min 0.000 [get_ports {sd_miso}]
set_output_delay -clock [get_clocks {sd_spi_clk}] -max 6.000 [get_ports {sd_mosi sd_ncs}]
set_output_delay -clock [get_clocks {sd_spi_clk}] -min -6.000 [get_ports {sd_mosi sd_ncs}]
# Target external ports directly: TD maps MOSI/CS FFs into PAD; internal names change.
# CS actual RTL TB: minsetup90ns/minhold70ns, conservative40ns model.
# Setup: cardfall40 -> actual capture80; actuallaunch40 -> cardrise80.
set_multicycle_path 4 -setup -end -from [get_ports {sd_miso}]
set_multicycle_path 4 -setup -start -to [get_ports {sd_mosi sd_ncs}]
# Exact CE hold: nextcardfall40 vs previouscapture0; nextlaunch120 vs cardrise80.
# Must be confirmed by SPI timing TB AND routed edge reports before acceptance.
set_multicycle_path 7 -hold -end -from [get_ports {sd_miso}]
set_multicycle_path 7 -hold -start -to [get_ports {sd_mosi sd_ncs}]

# NOCOMP PLLs use dedicated internal VCO feedback. Output BUFGs retained.
# No external feedback routing directives needed; frequencies and phase relationships unchanged.
