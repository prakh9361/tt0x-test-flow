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
    // 1. INPUT MAPPING
    // ------------------------------------------------------------------------
    // ui_in: Serial Data In (for loading seeds)
    // ui_in[4]: Load Enable (1 = Shift in data, 0 = Generate Code)
    // ui_in[5]: Output Enable (1 = Enable output, 0 = Silence)
    
    wire data_in = ui_in;
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
    // 3. LOGIC EQUATIONS (Derived from Section X [2], [3])
    // ------------------------------------------------------------------------

    // --- R0 Feedback (Linear) ---
    // Recursion: R0(t+55) = R0(t+50)+R0(t+45)+R0(t+40)+R0(t+20)+R0(t+10)+R0(t+5)+R0(t)
    // We assume r0 is R0(t) and r0[6] is R0(t+50).
    wire r0_feedback;
    assign r0_feedback = r0[6] ^ r0[7] ^ r0[8] ^ r0[9] ^ r0[10] ^ r0[11] ^ r0;

    // --- R1 Linear Part (Self-Feedback) ---
    // Recursion part 1: R1(t+50)+R1(t+45)+R1(t+40)+R1(t+20)+R1(t+10)+R1(t+5)+R1(t)
    wire r1_self_feedback;
    assign r1_self_feedback = r1[6] ^ r1[7] ^ r1[8] ^ r1[9] ^ r1[10] ^ r1[11] ^ r1;

    // --- R1 Coupling Part (From R0) ---
    // Linear sum of R0 taps: R0(t+40)+R0(t+35)+R0(t+30)+R0(t+25)+R0(t+15)+R0(t)
    wire r0_coupling_sum;
    assign r0_coupling_sum = r0[8] ^ r0[12] ^ r0[13] ^ r0[14] ^ r0[15] ^ r0;

    // --- Sigma 2 Function (Nonlinear) ---
    // Inputs: 7 taps from R0 -> {50, 45, 40, 20, 10, 5, 0}
    // Output: Sum of all pairwise products.
    wire sigma_out;
    wire [6:0] s_in;
    assign s_in = {r0[6], r0[7], r0[8], r0[9], r0[10], r0[11], r0};
    
    // Implementing Sigma2: XOR sum of ANDs of all 21 unique pairs
    assign sigma_out = 
        (s_in & s_in[4]) ^ (s_in & s_in[5]) ^ (s_in & s_in[16]) ^ 
        (s_in & s_in[17]) ^ (s_in & s_in[11]) ^ (s_in & s_in[18]) ^
        (s_in[4] & s_in[5]) ^ (s_in[4] & s_in[16]) ^ (s_in[4] & s_in[17]) ^ 
        (s_in[4] & s_in[11]) ^ (s_in[4] & s_in[18]) ^
        (s_in[5] & s_in[16]) ^ (s_in[5] & s_in[17]) ^ (s_in[5] & s_in[11]) ^ (s_in[5] & s_in[18]) ^
        (s_in[16] & s_in[17]) ^ (s_in[16] & s_in[11]) ^ (s_in[16] & s_in[18]) ^
        (s_in[17] & s_in[11]) ^ (s_in[17] & s_in[18]) ^
        (s_in[11] & s_in[18]);

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
            r1 <= {r1[53:0], rf[17]};
            r0 <= {r0[53:0], r1[19]};
        end else if (out_en) begin
            // GENERATE MODE:
            // Advance R0 (Linear)
            r0 <= {r0[53:0], r0_feedback};
            // Advance R1 (Nonlinear Coupled)
            r1 <= {r1[53:0], r1_feedback};
            // Advance RF (Cyclic Rotation)
            rf <= {rf[3:0], rf[17]}; 
        end
    end

    // ------------------------------------------------------------------------
    // 5. OUTPUT ASSIGNMENT
    // ------------------------------------------------------------------------
    // Final sequence J(t) is the sum of the components.
    // uo_out: The JNAV PRN Code
    // uo_out[4]: Clock echo (debug)
    // uo_out[5]: Valid signal (high when out_en is high)

    wire jnav_bit = r0 ^ r1 ^ rf;
    
    assign uo_out = out_en ? jnav_bit : 1'b0;
    assign uo_out[4] = clk;
    assign uo_out[5] = out_en;
    assign uo_out[7:3] = 0;

    // Unused IOs
    assign uio_out = 0;
    assign uio_oe  = 0;

endmodule
