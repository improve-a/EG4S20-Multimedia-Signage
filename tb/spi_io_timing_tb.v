`timescale 1ns/1ps
// Unit pin-level timing model. nCS is driven by this TB, not sd_card_cmd.
module spi_io_timing_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, req = 0, ncs_ctrl = 1, miso = 0;
    reg [15:0] divider = 2;
    reg [7:0] tx = 0;
    wire sck, mosi, ncs, ack;
    wire [7:0] rx;
    spi_master dut(.sys_clk(clk), .rst(rst), .nCS(ncs), .DCLK(sck),
        .MOSI(mosi), .MISO(miso), .CPOL(1'b1), .CPHA(1'b1),
        .nCS_ctrl(ncs_ctrl), .clk_div(divider), .wr_req(req),
        .wr_ack(ack), .data_in(tx), .data_out(rx));

    localparam integer BYTE_COUNT = 8;
    reg [7:0] tx_vectors [0:BYTE_COUNT-1];
    reg [7:0] rx_vectors [0:BYTE_COUNT-1];
    reg run_active = 0, byte_active = 0;
    reg prev_sck = 1, prev_ack = 0;
    integer completed = 0, bit_count = 0, fall_count = 0;
    integer total_samples = 0, total_falls = 0, total_preloads = 0;
    integer mode_samples = 0, mode_falls = 0, mode_preloads = 0;
    integer high_samples = 0, low_samples = 0;
    integer half_ps = 40000;
    integer card_return_ps = 16000;
    time now_ps;
    time last_edge = 0, last_fall = 0, last_mosi_operation = 0;
    time last_sample = 0, previous_sample_half = 0;
    reg have_sample = 0;
    reg [7:0] active_tx = 0, active_rx = 0, card_tx_word = 0;
    reg [7:0] expected_rx_shift = 0;
    reg [2:0] pre_state, pre_edge_count;
    reg [7:0] pre_rx, pre_mosi_shift;
    reg pre_miso, pre_req, do_preload, do_rx_sample, do_tx_shift;
    reg rose, fell;

    // Card changes its output only after an observed falling SCLK pin edge.
    // Highspeed16ns = tOD14ns + PCB2ns; identification52ns = tOD50ns + PCB2ns.
    // Clock-output and FPGA-input internal physical delays are NOT simulated.
    always @(negedge sck) begin
        if (run_active && !rst && ncs === 1'b0) begin
            if (!byte_active || bit_count > 7)
                $fatal(1, "Unexpected selected falling SCLK edge at %0t", $time);
            miso <= #(card_return_ps/1000.0) rx_vectors[completed][7-bit_count];
        end
    end

    // Capture pre-NBA conditions, then inspect both DUT registers and output pins.
    // A 1ps observation delay avoids racing the DUT's nonblocking assignments.
    always @(posedge clk) begin
        pre_state = dut.state;
        pre_edge_count = dut.clk_edge_cnt[2:0];
        pre_rx = dut.MISO_shift;
        pre_mosi_shift = dut.MOSI_shift;
        pre_miso = miso;
        pre_req = req;
        do_preload = (pre_state == 0 && pre_req);
        do_rx_sample = (pre_state == 1 && pre_edge_count[0] == 1'b1);
        do_tx_shift = (pre_state == 1 && dut.clk_edge_cnt != 0 &&
                       pre_edge_count[0] == 1'b0);
        #0.001;
        now_ps = $rtoi($realtime*1000.0+0.5);
        rose = (prev_sck === 1'b0 && sck === 1'b1);
        fell = (prev_sck === 1'b1 && sck === 1'b0);
        if (run_active && !rst) begin
            if (ncs !== 1'b0) $fatal(1, "CS changed during selected unit transfer");
            if (do_preload) begin
                if (byte_active || completed >= BYTE_COUNT)
                    $fatal(1, "Unexpected or duplicate preload at %0t", $time);
                if (have_sample && now_ps-last_sample < previous_sample_half)
                    $fatal(1, "Last sample to next preload gap %0dps < %0dps",
                        now_ps-last_sample, previous_sample_half);
                if (sck !== 1'b1) $fatal(1, "CPOL1 preload while SCLK not high");
                byte_active = 1;
                bit_count = 0; fall_count = 0; card_tx_word = 0;
                active_tx = tx_vectors[completed]; active_rx = rx_vectors[completed];
                if (tx !== active_tx || dut.MOSI_shift !== active_tx)
                    $fatal(1, "Wrong initial MOSI preload byte %0d", completed);
                expected_rx_shift = 0;
                if (dut.MISO_shift !== 0) $fatal(1, "Receive shift not cleared on preload");
                last_edge = now_ps;
                last_mosi_operation = now_ps;
                mode_preloads = mode_preloads+1; total_preloads = total_preloads+1;
            end else begin
                if (dut.MISO_shift !== (do_rx_sample ? {pre_rx[6:0],pre_miso} : pre_rx))
                    $fatal(1, "MISO register changed outside rising CE or captured wrong pin");
            end

            if (do_tx_shift) begin
                if (!fell || !byte_active || bit_count < 1 || bit_count > 7)
                    $fatal(1, "MOSI shift not at a selected falling edge");
                if (have_sample && now_ps-last_sample < previous_sample_half)
                    $fatal(1, "MOSI hold %0dps < %0dps",
                        now_ps-last_sample, previous_sample_half);
                if (dut.MOSI_shift !== {pre_mosi_shift[6:0],pre_mosi_shift[7]})
                    $fatal(1, "MOSI shift value mismatch");
                last_mosi_operation = now_ps;
            end else if (!do_preload && dut.MOSI_shift !== pre_mosi_shift) begin
                $fatal(1, "MOSI register changed outside preload/falling shift");
            end

            if (rose || fell) begin
                if (!byte_active) $fatal(1, "SCLK edge outside an active byte");
                if (now_ps-last_edge != half_ps)
                    $fatal(1, "SCLK half period %0dps != %0dps",
                        now_ps-last_edge, half_ps);
                last_edge = now_ps;
            end
            if (fell) begin
                if (do_rx_sample) $fatal(1, "MISO sampled at falling edge");
                fall_count = fall_count+1; mode_falls = mode_falls+1;
                total_falls = total_falls+1;
                last_fall = now_ps;
            end
            if (do_rx_sample !== rose)
                $fatal(1, "MISO capture CE does not correspond exactly to SCLK rise");
            if (rose) begin
                if (bit_count >= 8 || fall_count != bit_count+1)
                    $fatal(1, "Missing or extra first/last SPI edge");
                if (now_ps-last_fall != half_ps || now_ps-last_fall < card_return_ps)
                    $fatal(1, "Card return sampled before delay/half-cycle complete");
                if (now_ps-last_mosi_operation < half_ps)
                    $fatal(1, "Card MOSI setup %0dps < %0dps",
                        now_ps-last_mosi_operation, half_ps);
                if (mosi !== active_tx[7-bit_count])
                    $fatal(1, "Card MOSI byte %0d bit %0d wrong", completed, bit_count);
                if (pre_miso !== active_rx[7-bit_count])
                    $fatal(1, "Delayed MISO byte %0d bit %0d wrong", completed, bit_count);
                card_tx_word = {card_tx_word[6:0],mosi};
                expected_rx_shift = {expected_rx_shift[6:0],active_rx[7-bit_count]};
                if (dut.MISO_shift !== expected_rx_shift)
                    $fatal(1, "Receive scoreboard mismatch after sample");
                bit_count = bit_count+1;
                total_samples = total_samples+1; mode_samples = mode_samples+1;
                last_sample = now_ps; previous_sample_half = half_ps; have_sample = 1;
                if (bit_count == 8 && card_tx_word !== active_tx)
                    $fatal(1, "Complete transmitted byte mismatch");
            end
            if (ack && !prev_ack) begin
                if (!byte_active || bit_count != 8 || fall_count != 8 || rx !== active_rx)
                    $fatal(1, "ACK before 8 complete correct receive bits");
                byte_active = 0; completed = completed+1;
            end
        end
        prev_sck = sck; prev_ack = ack;
    end

    task run_mode;
        input [15:0] div_value;
        input real expected_half;
        integer i;
        begin
            @(negedge clk);
            divider = div_value; half_ps = $rtoi(expected_half*1000.0+0.5);
            if (div_value == 2) card_return_ps = 16000;
            else if (div_value == 248) card_return_ps = 52000;
            else $fatal(1, "Unsupported card timing mode");
            completed = 0; mode_samples = 0; mode_falls = 0; mode_preloads = 0;
            tx = tx_vectors[0]; ncs_ctrl = 0; run_active = 1; req = 1;
            // Keep req asserted across ACK. Change data 1ns after ACK, so the
            // earliest next IDLE preload is exercised rather than inserting a gap.
            for (i=0; i<BYTE_COUNT; i=i+1) begin
                @(posedge ack); #1;
                if (completed != i+1) $fatal(1, "ACK scoreboard count mismatch");
                if (i+1 < BYTE_COUNT) tx = tx_vectors[i+1];
                else req = 0;
            end
            repeat (8) @(posedge clk);
            @(negedge clk);
            now_ps = $rtoi($realtime*1000.0+0.5);
            if (now_ps-last_sample < half_ps)
                $fatal(1, "Final byte MOSI hold interval incomplete");
            if (byte_active || completed != BYTE_COUNT || mode_samples != 64 ||
                mode_falls != 64 || mode_preloads != BYTE_COUNT || sck !== 1'b1)
                $fatal(1, "Mode completeness/idle check failed divider=%0d", div_value);
            if (div_value == 2) high_samples = mode_samples;
            else low_samples = mode_samples;
            ncs_ctrl = 1; run_active = 0;
            $display("MODE_CHECK divider=%0d half=%0.0fns bytes=%0d samples=%0d falls=%0d card_return_ps=%0d",
                div_value, expected_half, completed, mode_samples, mode_falls, card_return_ps);
        end
    endtask

    initial begin
        tx_vectors[0]=8'ha5; tx_vectors[1]=8'h5a; tx_vectors[2]=8'h00; tx_vectors[3]=8'hff;
        tx_vectors[4]=8'h81; tx_vectors[5]=8'h7e; tx_vectors[6]=8'hc3; tx_vectors[7]=8'h3c;
        rx_vectors[0]=8'h3c; rx_vectors[1]=8'hc3; rx_vectors[2]=8'h81; rx_vectors[3]=8'h7e;
        rx_vectors[4]=8'h00; rx_vectors[5]=8'hff; rx_vectors[6]=8'ha5; rx_vectors[7]=8'h5a;
        repeat (3) @(negedge clk); rst = 0;
        repeat (3) @(posedge clk);
        run_mode(16'd2, 40.0);
        run_mode(16'd248, 2500.0);
        if (high_samples != 64 || low_samples != 64 || total_samples != 128 ||
            total_falls != 128 || total_preloads != 16)
            $fatal(1, "Final aggregate coverage count mismatch");
        $display("TEST_PASS spi_io_timing CPOL1CPHA1 sys100 div2_div248 bytes16 bits128 MISO_delay16_52ns setup_hold_CE_checked");
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Watchdog: SPI timing test did not finish");
    end
endmodule

// Real command-controller CS timing. All-zero R1 is an intentionally simple
// card response; this top does not claim complete SD protocol/card compliance.
module spi_cs_timing_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, cmd_req = 0;
    reg [15:0] spi_div = 248;
    reg [47:0] cmd = 48'h000000000095;
    wire cmd_ack, cmd_error, cs_ctrl, spi_req, spi_ack;
    wire [15:0] active_div;
    wire [7:0] spi_tx, spi_rx;
    wire ncs, sck, mosi;
    sd_card_cmd #(.RESPONSE_TIMEOUT_BYTES(16), .TOKEN_TIMEOUT_BYTES(16)) controller(
        .sys_clk(clk), .rst(rst), .cmd_response(), .block_read_error(),
        .block_error_code(), .spi_clk_div(spi_div), .cmd_req(cmd_req),
        .cmd_req_ack(cmd_ack), .cmd_req_error(cmd_error), .cmd(cmd),
        .cmd_r1(8'h00), .cmd_data_len(16'd0), .block_read_req(1'b0),
        .block_read_valid(), .block_read_data(), .block_read_req_ack(),
        .block_write_req(1'b0), .block_write_data(8'h00), .block_write_data_rd(),
        .block_write_req_ack(), .nCS_ctrl(cs_ctrl), .clk_div(active_div),
        .spi_wr_req(spi_req), .spi_wr_ack(spi_ack), .spi_data_in(spi_tx),
        .spi_data_out(spi_rx));
    spi_master master(.sys_clk(clk), .rst(rst), .nCS(ncs), .DCLK(sck),
        .MOSI(mosi), .MISO(1'b0), .CPOL(1'b1), .CPHA(1'b1),
        .nCS_ctrl(cs_ctrl), .clk_div(active_div), .wr_req(spi_req),
        .wr_ack(spi_ack), .data_in(spi_tx), .data_out(spi_rx));

    integer asserts = 0, deasserts = 0, selected_rises = 0, command_count = 0;
    integer low_commands = 0, high_commands = 0;
    reg selected = 0;
    time assert_time = 0, last_selected_rise = 0;
    time min_setup = 1000000000000, min_hold = 1000000000000;
    time gap;
    time now_ps;
    reg [15:0] selected_div;

    always @(negedge ncs) begin
        if (!rst) begin
            if (selected) $fatal(1, "Duplicate CS assertion");
            if (controller.state != controller.S_CMD)
                $fatal(1, "CS assertion outside real S_CMD state");
            selected = 1; selected_rises = 0; assert_time = $rtoi($realtime*1000.0+0.5);
            selected_div = active_div; asserts = asserts+1;
            if (selected_div != 2 && selected_div != 248)
                $fatal(1, "Wrong actual command SPI divider");
        end
    end
    always @(posedge sck) begin
        if (!rst && ncs === 1'b0) begin
            if (!selected) $fatal(1, "Selected SCLK rise without CS assertion");
            if (active_div !== selected_div)
                $fatal(1, "SPI divider changed while CS-selected");
            if (selected_rises == 0) begin
                now_ps = $rtoi($realtime*1000.0+0.5);
                gap = now_ps-assert_time;
                if (gap < 40000) $fatal(1, "Real CS setup %0dps < 40000ps", gap);
                if (gap < min_setup) min_setup = gap;
                $display("CS_SETUP divider=%0d gap_ns=%0.3f", selected_div, gap/1000.0);
            end
            selected_rises = selected_rises+1;
            last_selected_rise = $rtoi($realtime*1000.0+0.5);
        end
    end
    always @(posedge ncs) begin
        if (!rst && selected) begin
            if (controller.state != controller.S_CMD_PRE)
                $fatal(1, "CS deassertion outside real S_CMD_PRE state");
            if (selected_rises != 56)
                $fatal(1, "CS deasserted before six command bytes plus R1 byte");
            now_ps = $rtoi($realtime*1000.0+0.5);
            gap = now_ps-last_selected_rise;
            if (gap < 40000) $fatal(1, "Real CS hold %0dps < 40000ps", gap);
            if (gap < min_hold) min_hold = gap;
            $display("CS_HOLD divider=%0d gap_ns=%0.3f", selected_div, gap/1000.0);
            selected = 0; deasserts = deasserts+1;
        end
    end

    task issue_command;
        input [15:0] div_value;
        input [47:0] command_value;
        begin
            wait (controller.state == controller.S_WAIT);
            @(negedge clk);
            spi_div = div_value; cmd = command_value;
            // S_WAIT must latch the requested divider before entering S_CMD_PRE.
            repeat (2) @(negedge clk);
            cmd_req = 1;
            @(posedge cmd_ack); #1;
            if (cmd_error || !selected || selected_div !== div_value ||
                selected_rises != 56 || spi_rx !== 0)
                $fatal(1, "Simple command/response or selected-edge count failed");
            command_count = command_count+1;
            if (div_value == 248) low_commands = low_commands+1;
            else high_commands = high_commands+1;
            @(negedge clk); cmd_req = 0;
            wait (controller.state == controller.S_WAIT);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst = 0;
        issue_command(16'd248, 48'h000000000095);
        issue_command(16'd248, 48'h08000001aa87);
        issue_command(16'd2, 48'h170000000001);
        issue_command(16'd2, 48'h110000000001);
        // S_END intentionally leaves CS low. Trigger a real next S_CMD_PRE
        // to observe the final command's deassertion, then stop before it asserts.
        @(negedge clk); cmd_req = 1;
        @(posedge ncs); #1;
        if (command_count != 4 || low_commands != 2 || high_commands != 2 ||
            asserts != 4 || deasserts != 4 || selected || min_setup < 40000 || min_hold < 40000)
            $fatal(1, "CS coverage/minimum-interval completeness failed");
        $display("TEST_PASS spi_cs_timing real_sd_card_cmd commands4 low2_high2 min_setup_ns=%0.3f min_hold_ns=%0.3f", min_setup/1000.0, min_hold/1000.0);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Watchdog: real CS timing test did not finish");
    end
endmodule
