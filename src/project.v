/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // 1. Define the 56-bit register
    reg [55:0] d;

    // 2. IO logic (all disabled/zero)
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    
    // 3. Sequential logic: Load the 56-bit register
    always @(posedge clk) begin
        if (!rst_n) begin
            d <= 56'b0;
        end else begin
            // This loads the current ui_in into the bottom 8 bits 
            // and shifts the rest up.
            d <= {d[47:0], ui_in}; 
        end
    end

    // 4. Combinational logic: The Mux
    // We use a continuous assignment so uo_out stays a wire.
    // ui_in[2:0] selects which byte of 'd' to show.
    assign uo_out = (ui_in[2:0] == 3'b000) ? d[7:0]   :
                    (ui_in[2:0] == 3'b001) ? d[15:8]  :
                    (ui_in[2:0] == 3'b010) ? d[23:16] :
                    (ui_in[2:0] == 3'b011) ? d[31:24] :
                    (ui_in[2:0] == 3'b100) ? d[39:32] :
                    (ui_in[2:0] == 3'b101) ? d[47:40] :
                    (ui_in[2:0] == 3'b110) ? d[55:48] : 8'b0;

    // List all unused inputs to prevent linter warnings
    wire _unused = &{ena, uio_in, ui_in[7:3], 1'b0};

endmodule
