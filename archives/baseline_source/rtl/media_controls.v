// HX4S20C controls. All outputs belong to clk (the SD system clock).
// Physical KEY2 next; KEY4 auto/manual; KEY3 short pause, long mute.
module media_controls #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer LONG_PRESS_MS = 1000
)(
    input wire clk, rst,
    input wire key_next, key_auto, key_pause_mute,
    output wire next_pulse,
    output reg auto_mode, paused, muted,
    output reg mode_changed
);
    wire auto_press, pause_press, pause_release, pause_down;
    localparam integer HOLD_CYCLES = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;
    reg [31:0] hold_count;
    reg long_done;
    reg key_held;
    media_button #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) next_button
        (.clk(clk), .rst(rst), .button(key_next), .press(next_pulse), .release_pulse(), .down());
    media_button #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) auto_button
        (.clk(clk), .rst(rst), .button(key_auto), .press(auto_press), .release_pulse(), .down());
    media_button #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS)) pause_button
        (.clk(clk), .rst(rst), .button(key_pause_mute), .press(pause_press),
         .release_pulse(pause_release), .down(pause_down));
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            auto_mode <= 1'b0;
            paused <= 1'b0;
            muted <= 1'b0;
            mode_changed <= 1'b0;
            hold_count <= 0;
            long_done <= 0;
            key_held <= 0;
        end else begin
            mode_changed <= 0;
            if (auto_press) begin
                auto_mode <= ~auto_mode;
                mode_changed <= 1;
            end
            if (pause_press) begin
                key_held <= 1;
                hold_count <= 0;
                long_done <= 0;
            end else if (pause_release) begin
                key_held <= 0;
                hold_count <= 0;
                if (key_held && !long_done) begin
                    paused <= ~paused;
                    mode_changed <= 1;
                end
            end else if (key_held && pause_down && !long_done) begin
                if (hold_count >= HOLD_CYCLES - 1) begin
                    muted <= ~muted;
                    long_done <= 1;
                end else hold_count <= hold_count + 1'b1;
            end
        end
    end
endmodule

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
            meta <= 1; synced <= 1; stable <= 1;
            count <= 0; press <= 0; release_pulse <= 0;
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
