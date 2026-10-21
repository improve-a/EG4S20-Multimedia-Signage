// One-cycle RGB adjustment. Configuration is synchronous to clk and is held
// stable for each frame by the caller. RGB is R:G:B, eight bits each.
module pixel_adjust (
    input wire clk, rst,
    input wire i_hs, i_vs, i_de,
    input wire [23:0] i_rgb,
    input wire signed [8:0] brightness,
    input wire [2:0] contrast,
    output reg o_hs, o_vs, o_de,
    output reg [23:0] o_rgb
);
    // Contrast is 2/4 through 8/4. Illegal settings use unity.
    function [7:0] adjust;
        input [7:0] pixel;
        input signed [8:0] bright;
        input [2:0] level;
        reg signed [12:0] centered, scaled, value;
        
        begin
            centered = $signed({1'b0,pixel}) - 13'sd128;
            // Quartile multiplication uses shifts and adds, no DSP needed.
            case (level)
                3'd0: scaled = centered <<< 1;
                3'd1: scaled = (centered <<< 1) + centered;
                3'd3: scaled = (centered <<< 2) + centered;
                3'd4: scaled = (centered <<< 2) + (centered <<< 1);
                3'd5: scaled = (centered <<< 3) - centered;
                3'd6: scaled = centered <<< 3;
                default: scaled = centered <<< 2;
            endcase
            scaled = scaled >>> 2;
            value = scaled + 13'sd128 + bright;
            if (value < 0) adjust = 8'd0;
            else if (value > 13'sd255) adjust = 8'd255;
            else adjust = value[7:0];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            o_hs <= 1'b0;
            o_vs <= 1'b0;
            o_de <= 1'b0;
            o_rgb <= 24'd0;
        end else begin
            o_hs <= i_hs;
            o_vs <= i_vs;
            o_de <= i_de;
            o_rgb <= i_de ? {adjust(i_rgb[23:16],brightness,contrast),
                             adjust(i_rgb[15:8],brightness,contrast),
                             adjust(i_rgb[7:0],brightness,contrast)} : 24'd0;
        end
    end
endmodule
