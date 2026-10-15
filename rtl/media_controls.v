// HX4S20C controls. All outputs belong to clk (the SD system clock).
// Active-low physical keys: KEY2 next/parameter up, KEY4 auto/parameter down
// and long-press mode navigation, KEY3 short pause / long mute.
module media_controls #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer LONG_PRESS_MS = 1000,
    parameter integer AUTO_PERIOD_SECONDS = 3
)(
    input wire clk, rst,
    input wire key_next, key_auto, key_pause_mute,
    output reg next_pulse,
    output reg content_mode, content_mode_changed,
    output reg auto_mode, paused, muted,
    output reg mode_changed,
    output reg [2:0] mode,
    output reg signed [8:0] brightness,
    output reg [2:0] contrast,
    output reg [7:0] interval_seconds,
    output reg osd_enable,
    output reg [1:0] transition_mode,
    output reg [1:0] scale_mode,
    output reg [3:0] volume,
    output reg param_changed
);
    wire next_press, next_release, next_down, key4_press, key4_release, key4_down;
    wire pause_press, pause_release, pause_down;
    localparam integer HOLD_CYCLES = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;
    localparam [7:0] DEFAULT_INTERVAL =
        (AUTO_PERIOD_SECONDS < 1) ? 8'd1 :
        (AUTO_PERIOD_SECONDS > 15) ? 8'd15 : AUTO_PERIOD_SECONDS[7:0];

    reg [31:0] pause_hold_count;
    reg pause_long_done, pause_key_held;
    reg [31:0] key4_hold_count;
    reg key4_long_done, key4_key_held;

    reg [31:0] next_hold_count;
    reg next_long_done, next_key_held, next_play_held;

    media_button #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) next_button
        (.clk(clk), .rst(rst), .button(key_next), .press(next_press), .release_pulse(next_release), .down(next_down));
    media_button #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) auto_button
        (.clk(clk), .rst(rst), .button(key_auto), .press(key4_press),
         .release_pulse(key4_release), .down(key4_down));
    media_button #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) pause_button
        (.clk(clk), .rst(rst), .button(key_pause_mute), .press(pause_press),
         .release_pulse(pause_release), .down(pause_down));

    // The control state is reset on the local clock. The physical-key
    // synchronizer/debouncers below keep their asynchronous assertion reset.
    always @(posedge clk) begin
        if (rst) begin
            next_pulse <= 0; content_mode <= 0; content_mode_changed <= 0;
            next_hold_count <= 0; next_long_done <= 0; next_key_held <= 0; next_play_held <= 0;
            auto_mode <= 1'b0;
            paused <= 1'b0;
            muted <= 1'b0;
            mode_changed <= 1'b0;
            mode <= 3'd0;
            brightness <= 9'sd0;
            contrast <= 3'd2;
            interval_seconds <= DEFAULT_INTERVAL;
            osd_enable <= 1'b1;
            transition_mode <= 2'd0;
            scale_mode <= 2'd0;
            volume <= 4'd8;
            param_changed <= 1'b0;
            pause_hold_count <= 0;
            pause_long_done <= 0;
            pause_key_held <= 0;
            key4_hold_count <= 0;
            key4_long_done <= 0;
            key4_key_held <= 0;
        end else begin
            mode_changed <= 1'b0;
            param_changed <= 1'b0;
            next_pulse <= 0; content_mode_changed <= 0;
            // PLAY gestures resolve on release or the long threshold, never both.
            // Latch the page at press so simultaneous page navigation cannot create a next.
            if (next_press) begin
                next_key_held <= 1; next_play_held <= (mode == 0);
                next_hold_count <= 0; next_long_done <= 0;
            end else if (next_release) begin
                next_key_held <= 0; next_hold_count <= 0;
                if (next_key_held && next_play_held && !next_long_done && mode == 0) next_pulse <= 1;
            end else if (next_key_held && next_play_held && next_down && !next_long_done) begin
                if (next_hold_count >= HOLD_CYCLES - 1) begin
                    content_mode <= ~content_mode; content_mode_changed <= 1;
                    mode_changed <= 1; next_long_done <= 1;
                end else next_hold_count <= next_hold_count + 1'b1;
            end

            // KEY4 long press changes the control page once. Its release is
            // deliberately consumed, so it can never also toggle auto/change a value.
            if (key4_press) begin
                key4_key_held <= 1'b1;
                key4_hold_count <= 0;
                key4_long_done <= 1'b0;
            end else if (key4_release) begin
                key4_key_held <= 1'b0;
                key4_hold_count <= 0;
                if (key4_key_held && !key4_long_done) begin
                    case (mode)
                        3'd0: begin
                            auto_mode <= ~auto_mode;
                            mode_changed <= 1'b1;
                        end
                        3'd1: if (brightness != -9'sd128) begin
                            brightness <= (brightness < -9'sd112) ? -9'sd128 : brightness - 9'sd16;
                            param_changed <= 1'b1;
                        end
                        3'd2: if (contrast != 0) begin
                            contrast <= contrast - 1'b1;
                            param_changed <= 1'b1;
                        end
                        3'd3: if (interval_seconds > 1) begin
                            interval_seconds <= interval_seconds - 1'b1;
                            mode_changed <= 1'b1;
                            param_changed <= 1'b1;
                        end
                        3'd4: begin osd_enable <= ~osd_enable; param_changed <= 1'b1; end
                        3'd5: begin
                            transition_mode <= (transition_mode == 0) ? 2'd2 : transition_mode - 1'b1;
                            param_changed <= 1'b1;
                        end
                        3'd6: begin scale_mode <= {1'b0, ~scale_mode[0]}; param_changed <= 1'b1; end
                        3'd7: if (volume != 0) begin
                            volume <= volume - 1'b1;
                            param_changed <= 1'b1;
                        end
                        default: ;
                    endcase
                end
            end else if (key4_key_held && key4_down && !key4_long_done) begin
                if (key4_hold_count >= HOLD_CYCLES - 1) begin
                    mode <= mode + 1'b1; // 3-bit mode naturally wraps 7 -> 0.
                    key4_long_done <= 1'b1;
                    param_changed <= 1'b1;
                end else begin
                    key4_hold_count <= key4_hold_count + 1'b1;
                end
            end

            // KEY2 is a next-picture press in page 0 and increments/toggles
            // the selected setting in pages 1..7.
            if (next_press && mode != 3'd0) begin
                case (mode)
                    3'd1: if (brightness != 9'sd127) begin
                        brightness <= (brightness > 9'sd111) ? 9'sd127 : brightness + 9'sd16;
                        param_changed <= 1'b1;
                    end
                    3'd2: if (contrast < 6) begin
                        contrast <= contrast + 1'b1;
                        param_changed <= 1'b1;
                    end
                    3'd3: if (interval_seconds < 15) begin
                        interval_seconds <= interval_seconds + 1'b1;
                        mode_changed <= 1'b1;
                        param_changed <= 1'b1;
                    end
                    3'd4: begin osd_enable <= ~osd_enable; param_changed <= 1'b1; end
                    3'd5: begin
                        transition_mode <= (transition_mode == 2) ? 2'd0 : transition_mode + 1'b1;
                        param_changed <= 1'b1;
                    end
                    3'd6: begin scale_mode <= {1'b0, ~scale_mode[0]}; param_changed <= 1'b1; end
                    3'd7: if (volume < 8) begin
                        volume <= volume + 1'b1;
                        param_changed <= 1'b1;
                    end
                    default: ;
                endcase
            end

            // KEY3 retains its original short-pause / long-mute behavior.
            if (pause_press) begin
                pause_key_held <= 1'b1;
                pause_hold_count <= 0;
                pause_long_done <= 0;
            end else if (pause_release) begin
                pause_key_held <= 0;
                pause_hold_count <= 0;
                if (pause_key_held && !pause_long_done) begin
                    paused <= ~paused;
                    mode_changed <= 1'b1;
                end
            end else if (pause_key_held && pause_down && !pause_long_done) begin
                if (pause_hold_count >= HOLD_CYCLES - 1) begin
                    muted <= ~muted;
                    pause_long_done <= 1;
                end else pause_hold_count <= pause_hold_count + 1'b1;
            end
        end
    end
endmodule

// Two-flop synchronizer followed by stable-state debounce for active-low keys.
module media_button #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input wire clk, rst, button,
    output reg press, release_pulse,
    output wire down
);
    localparam integer STABLE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    reg meta, synced, stable;
    reg [31:0] count;
    assign down = ~stable;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            meta <= 1'b1;
            synced <= 1'b1;
            stable <= 1'b1;
            count <= 0;
            press <= 0;
            release_pulse <= 0;
        end else begin
            meta <= button;
            synced <= meta;
            press <= 0;
            release_pulse <= 0;
            if (synced == stable) count <= 0;
            else if (count >= STABLE_CYCLES-1) begin
                stable <= synced;
                count <= 0;
                press <= ~synced;
                release_pulse <= synced;
            end else count <= count + 1'b1;
        end
    end
endmodule
