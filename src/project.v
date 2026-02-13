/*
 * Morse to English Decoder
 * Logic: Binary Tree Traversal
 * ui_in[0]: Dot pulse (active high)
 * ui_in[1]: Dash pulse (active high)
 * ui_in[2]: Submit/End-of-character pulse (active high)
 */

`default_nettype none

module tt_um_morse_decoder (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs (ASCII)
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Internal state
    reg [5:0] tree_index;   // Supports up to 63 nodes (Morse is max 5 deep for letters/nums)
    reg [7:0] ascii_char;
    
    // Simple edge detection to prevent multiple triggers on one press
    reg [2:0] ui_in_prev;
    wire dot_pressed  = (ui_in[0] && !ui_in_prev[0]);
    wire dash_pressed = (ui_in[1] && !ui_in_prev[1]);
    wire send_pressed = (ui_in[2] && !ui_in_prev[2]);

    // Assign outputs
    assign uo_out  = ascii_char;
    assign uio_out = 0;
    assign uio_oe  = 0;

    always @(posedge clk) begin
        if (!rst_n) begin
            tree_index <= 0;
            ascii_char <= 8'h00;
            ui_in_prev <= 0;
        end else begin
            ui_in_prev <= ui_in[2:0];

            if (dot_pressed) begin
                // Move to left child: (current * 2) + 1
                tree_index <= (tree_index << 1) + 1;
            end 
            else if (dash_pressed) begin
                // Move to right child: (current * 2) + 2
                tree_index <= (tree_index << 1) + 2;
            end 
            else if (send_pressed) begin
                // Convert tree position to ASCII
                case (tree_index)
                    1:  ascii_char <= 8'h45; // E (.)
                    2:  ascii_char <= 8'h54; // T (-)
                    3:  ascii_char <= 8'h49; // I (..)
                    4:  ascii_char <= 8'h41; // A (.-)
                    5:  ascii_char <= 8'h4E; // N (-.)
                    6:  ascii_char <= 8'h4D; // M (--)
                    7:  ascii_char <= 8'h53; // S (...)
                    8:  ascii_char <= 8'h55; // U (..-)
                    9:  ascii_char <= 8'h52; // R (.-.)
                    10: ascii_char <= 8'h57; // W (.--)
                    11: ascii_char <= 8'h44; // D (-..)
                    12: ascii_char <= 8'h4B; // K (-.-)
                    13: ascii_char <= 8'h47; // G (--.)
                    14: ascii_char <= 8'h4F; // O (---)
                    15: ascii_char <= 8'h48; // H (....)
                    16: ascii_char <= 8'h56; // V (...-)
                    17: ascii_char <= 8'h4C; // L (.-..)
                    19: ascii_char <= 8'h46; // F (..-.)
                    20: ascii_char <= 8'h50; // P (.--.)
                    21: ascii_char <= 8'h58; // X (-..-)
                    22: ascii_char <= 8'h4A; // J (.---)
                    23: ascii_char <= 8'h42; // B (-...)
                    24: ascii_char <= 8'h59; // Y (-.--)
                    25: ascii_char <= 8'h43; // C (-.-.)
                    26: ascii_char <= 8'h51; // Q (--.-)
                    27: ascii_char <= 8'h5A; // Z (--..)
                    default: ascii_char <= 8'h3F; // '?' for unknown
                endcase
                // Reset for next character
                tree_index <= 0;
            end
        end
    end

    // List unused pins
    wire _unused = &{ui_in[7:3], uio_in, ena, 1'b0};

endmodule
