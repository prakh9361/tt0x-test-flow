/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uo_out,   // Dedicated outputs
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // ------------------------------------------------------------------------
    // 0. LINT CLEANUP
    // ------------------------------------------------------------------------
    // Silence unused signal warnings by logically combining them
    wire _unused_ok = &{ena, uio_in, ui_in[7:6], ui_in[3:1]};

    // ------------------------------------------------------------------------
    // 1. INPUT MAPPING
    // ------------------------------------------------------------------------
    // ui_in: Serial Data In (for loading seeds)
    // ui_in[4]: Load Enable (1 = Shift in data, 0 = Generate Code)
    // ui_in[5]: Output Enable (1 = Enable output, 0 = Silence)
    
    wire data_in = ui_in[0]; // Assuming data is on LSB, or adjust specific bit
    wire load_en = ui_in[4];
    wire out_en  = ui_in[5];

    // ------------------------------------------------------------------------
    // 2. REGISTER DEFINITIONS (Total State: 115 bits)
    // ------------------------------------------------------------------------
    // R0: Upper 55-bit Linear Register
    // R1: Middle 55-bit Nonlinear/Coupled Register
    // RF: Lower 5-bit Flipping Factor Register
    
    reg [54:0] r0;
    reg [54:0] r1;
    reg [4:0]  rf;

    // ------------------------------------------------------------------------
    // 3. LOGIC EQUATIONS
    // ------------------------------------------------------------------------

    // --- R0 Feedback (Linear) ---
    // Recursion: R0(t+55) = ...
    wire r0_feedback;
    assign r0_feedback = r0[6] ^ r0[7] ^ r0[8] ^ r0[9] ^ r0[10] ^ r0[11] ^ r0[0];

    // --- R1 Linear Part (Self-Feedback) ---
    wire r1_self_feedback;
    assign r1_self_feedback = r1[6] ^ r1[7] ^ r1[8] ^ r1[9] ^ r1[10] ^ r1[11] ^ r1[0];

    // --- R1 Coupling Part (From R0) ---
    wire r0_coupling_sum;
    assign r0_coupling_sum = r0[8] ^ r0[12] ^ r0[13] ^ r0[14] ^ r0[15] ^ r0[0];

    // --- Sigma 2 Function (Nonlinear) ---
    // Inputs: 7 taps from R0 -> {50, 45, 40, 20, 10, 5, 0}
    // Output: Sum of all pairwise products.
    reg sigma_out;
    wire [6:0] s_in;
    // FIXED: Explicit selection of bit 0 instead of the whole 55-bit 'r0' vector
    assign s_in = {r0[6], r0[7], r0[8], r0[9], r0[10], r0[11], r0[0]};
    
    // FIXED: Replaced hardcoded out-of-bounds logic with an actual pairwise product loop
    // Implementation: XOR sum of ANDs of all unique pairs (i < j)
    integer i, j;
    reg sigma_accum;
    
    always @* begin
        sigma_accum = 1'b0;
        for (i = 0; i < 7; i = i + 1) begin
            for (j = i + 1; j < 7; j = j + 1) begin
                sigma_accum = sigma_accum ^ (s_in[i] & s_in[j]);
            end
        end
        sigma_out = sigma_accum;
    end

    // --- Total R1 Feedback ---
    // R1_next = Self_Feedback + (Coupling_Sum * Sigma_Out)
    wire r1_feedback;
    assign r1_feedback = r1_self_feedback ^ (r0_coupling_sum & sigma_out);

    // ------------------------------------------------------------------------
    // 4. STATE MACHINE / SHIFT LOGIC
    // ------------------------------------------------------------------------
    
    always @(posedge clk) begin
        if (!rst_n) begin
            r0 <= 55'd0;
            r1 <= 55'd0;
            rf <= 5'd0;
        end else if (load_en) begin
            // SERIAL LOAD MODE:
            // Shift data in from ui_in. Chain: r0 <- r1 <- rf <- data_in
            rf <= {rf[3:0], data_in};
            // FIXED: rf[17] was out of bounds (rf is 5 bits). Using MSB rf[4].
            r1 <= {r1[53:0], rf[4]}; 
            r0 <= {r0[53:0], r1[54]}; // Assuming chain from R1 MSB
        end else if (out_en) begin
            // GENERATE MODE:
            // Advance R0 (Linear)
            r0 <= {r0[53:0], r0_feedback};
            // Advance R1 (Nonlinear Coupled)
            r1 <= {r1[53:0], r1_feedback};
            // Advance RF (Cyclic Rotation)
            // FIXED: rf[17] was out of bounds. Using MSB rf[4] for rotation.
            rf <= {rf[3:0], rf[4]}; 
        end
    end

    // ------------------------------------------------------------------------
    // 5. OUTPUT ASSIGNMENT
    // ------------------------------------------------------------------------
    // uo_out[0]: The JNAV PRN Code
    // uo_out[4]: Clock echo (debug)
    // uo_out[5]: Valid signal
    
    // FIXED: XORing full registers (55 bits) produces a 55-bit vector. 
    // We likely want the MSB (the output bit) of the registers.
    wire jnav_bit = r0[54] ^ r1[54] ^ rf[4];
    
    // FIXED: Resolved MULTIDRIVEN error by using a single concatenation assignment
    assign uo_out = {
        2'b00,                      // uo_out[7:6]
        out_en,                     // uo_out[5] (Valid)
        clk,                        // uo_out[4] (Clock echo)
        3'b000,                     // uo_out[3:1]
        (out_en ? jnav_bit : 1'b0)  // uo_out[0] (Data)
    };

    // Unused IOs
    assign uio_out = 0;
    assign uio_oe  = 0;

endmodule
