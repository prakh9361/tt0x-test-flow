/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output reg  [7:0] uio_out,  // IOs: Output path (Changed to reg for assignment)
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // 1. Define the 56-bit register
    reg [55:0] d;

    // 2. IO logic - keeping these as inputs for now to avoid floating pins
    assign uio_oe  = 8'b00000000;
    
    // 3. Register logic
    // On reset, clear the register. Otherwise, shift or load data.
    always @(posedge clk) begin
        if (!rst_n) begin
            d <= 56'b0;
            uio_out <= 8'b0;
        end else begin
            // Example: Load the 8-bit input into the register and shift
            d <= {d[47:0], ui_in}; 
        end
    end

    // 4. Multiplexer logic
    // Since we can't output 56 bits at once, we use ui_in[2:0] to pick a byte.
    // 3 bits can select 8 different combinations (0-7).
    // 56 bits / 8 bits = 7 chunks.
    always @(*) begin
        case (ui_in[2:0])
            3'b000: uo_out = d[7:0];
            3'b001: uo_out = d[15:8];
            3'b010: uo_out = d[23:16];
            3'b011: uo_out = d[31:24];
            3'b100: uo_out = d[39:32];
            3'b101: uo_out = d[47:40];
            3'b110: uo_out = d[55:48];
            default: uo_out = 8'b0;
        endcase
    end

    // List all unused inputs to prevent linter warnings
    wire _unused = &{ena, uio_in, ui_in[7:3], 1'b0};

endmodule
