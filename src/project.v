/*
 * Copyright (c) 2024 NavIC Pilot Generator
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_navic_pilot_gen (
    input  wire [7:0] ui_in,    // Input: ui_in[5:0] selects PRN ID (1-63)
    input  wire [7:0] uio_in,   // IOs: Input path (Unused)
    output wire [7:0] uo_out,   // Output: uo_out[0] = Pilot Signal
    output wire [7:0] uio_out,  // IOs: Output path (Debug signals)
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (Active Low)
);

    // -------------------------------------------------------------------------
    // 1. Parameter / Initial Condition Selection Logic
    // -------------------------------------------------------------------------
    
    wire [5:0] prn_id = ui_in[5:0];
    
    // Registers to hold the selected Initial Conditions
    reg [54:0] P_R0_INIT;
    reg [54:0] P_R1_INIT;
    reg [4:0]  P_C_INIT;
    reg [9:0]  S_R0_INIT;
    reg [9:0]  S_R1_INIT;

    // Lookup Table for Initial Conditions (Data from ICD Tables 8 & 9)
    always @(*) begin
        case (prn_id)
            6'd1: begin
                P_R0_INIT = 55'o0227743641272102303;
                P_R1_INIT = 55'o1667217344450257245;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b0110111011;
                S_R1_INIT = 10'b0100110000;
            end
            6'd2: begin
                P_R0_INIT = 55'o0603070242564637717;
                P_R1_INIT = 55'o0300642746017221737;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b0111101000;
                S_R1_INIT = 10'b0110000010;
            end
            6'd3: begin
                P_R0_INIT = 55'o0746325144437416120;
                P_R1_INIT = 55'o0474006332201753645;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b1100000001;
                S_R1_INIT = 10'b1110010001;
            end
            6'd4: begin
                P_R0_INIT = 55'o0023763714573206044;
                P_R1_INIT = 55'o0613606702460402137;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b0110110110;
                S_R1_INIT = 10'b0101110011;
            end
            6'd5: begin
                P_R0_INIT = 55'o0155575663373106723;
                P_R1_INIT = 55'o1465531713404064713;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b0100011000;
                S_R1_INIT = 10'b1011000110;
            end
            // ... Add PRN 6 to 63 here ...
            default: begin // Default to PRN 1 if ID is 0 or > 5
                P_R0_INIT = 55'o0227743641272102303;
                P_R1_INIT = 55'o1667217344450257245;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b0110111011;
                S_R1_INIT = 10'b0100110000;
            end
        case (prn_id) // This line is just a syntax fix placeholder, usually one case block
        endcase
    end

    // -------------------------------------------------------------------------
    // 2. Logic Implementation
    // -------------------------------------------------------------------------

    // Registers
    reg [54:0] p_r0, p_r1;
    reg [4:0]  p_c;
    reg [9:0]  s_r0, s_r1;
    reg [13:0] chip_count; // Counts 0 to 10229
    reg [10:0] sec_count;  // Counts 0 to 1799

    wire reset = !rst_n;

    // --- Primary Code Feedback Logic (IZ4) ---
    // Derived from ICD Equations 13-20
    wire p_r0_fb = p_r0[50] ^ p_r0[45] ^ p_r0[40] ^ p_r0[20] ^ p_r0[10] ^ p_r0[5] ^ p_r0[0];
    
    wire sigma_2a = (p_r0[50] ^ p_r0[45] ^ p_r0[40]) & (p_r0[20] ^ p_r0[10] ^ p_r0[5] ^ p_r0[0]);
    wire sigma_2b = ((p_r0[50] ^ p_r0[45]) & p_r0[40]) ^ ((p_r0[20] ^ p_r0[10]) & (p_r0[5] ^ p_r0[0]));
    wire sigma_2c = (p_r0[50] & p_r0[45]) ^ (p_r0[20] & p_r0[10]) ^ (p_r0[5] & p_r0[0]);
    wire sigma_2  = sigma_2a ^ sigma_2b ^ sigma_2c;
    
    wire p_r1a = sigma_2 ^ (p_r0[40] ^ p_r0[35] ^ p_r0[30] ^ p_r0[25] ^ p_r0[15] ^ p_r0[0]);
    wire p_r1b = p_r1[50] ^ p_r1[45] ^ p_r1[40] ^ p_r1[20] ^ p_r1[10] ^ p_r1[5] ^ p_r1[0];
    wire p_r1_fb = p_r1a ^ p_r1b;

    wire p_c_fb = p_c[0]; // Pure cycling

    wire primary_code = p_c[0] ^ p_r1[0];

    // --- Secondary Code Feedback Logic ---
    // Derived from ICD Equations 21-27
    wire s_r0_fb = s_r0[5] ^ s_r0[2] ^ s_r0[1] ^ s_r0[0];

    wire s_sigma_2a = (s_r0[5] ^ s_r0[2]) & (s_r0[1] ^ s_r0[0]);
    wire s_sigma_2b = (s_r0[5] & s_r0[2]) ^ (s_r0[1] & s_r0[0]);
    wire s_sigma_2  = s_sigma_2a ^ s_sigma_2b;
    
    wire s_r1a = s_sigma_2 ^ s_r0[6] ^ s_r0[3] ^ s_r0[2] ^ s_r0[0];
    wire s_r1b = s_r1[5] ^ s_r1[2] ^ s_r1[1] ^ s_r1[0];
    wire s_r1_fb = s_r1a ^ s_r1b;

    wire secondary_code = s_r1[0]; 

    // --- State Machine ---
    wire primary_reset_condition = (chip_count == 10229);
    wire secondary_advance = primary_reset_condition; 
    wire secondary_reset_condition = (sec_count == 1799) && secondary_advance;

    always @(posedge clk) begin
        if (reset) begin
            // Load selected ICs on hard reset
            p_r0 <= P_R0_INIT;
            p_r1 <= P_R1_INIT;
            p_c  <= P_C_INIT;
            chip_count <= 0;
            
            s_r0 <= S_R0_INIT;
            s_r1 <= S_R1_INIT;
            sec_count <= 0;
        end else if (ena) begin
            // Primary Logic
            if (primary_reset_condition) begin
                // Short Cycle Reset: Reload current ICs (allows dynamic PRN switching here)
                p_r0 <= P_R0_INIT;
                p_r1 <= P_R1_INIT;
                p_c  <= P_C_INIT;
                chip_count <= 0;
            end else begin
                // Shift
                p_r0 <= {p_r0_fb, p_r0[54:1]};
                p_r1 <= {p_r1_fb, p_r1[54:1]};
                p_c  <= {p_c_fb,  p_c[4:1]};
                chip_count <= chip_count + 1;
            end

            // Secondary Logic
            if (secondary_advance) begin
                if (sec_count == 1799) begin
                    // Short Cycle Reset
                    s_r0 <= S_R0_INIT;
                    s_r1 <= S_R1_INIT;
                    sec_count <= 0;
                end else begin
                    // Shift
                    s_r0 <= {s_r0_fb, s_r0[9:1]};
                    s_r1 <= {s_r1_fb, s_r1[9:1]};
                    sec_count <= sec_count + 1;
                end
            end
        end
    end

    // --- Output Assignments ---
    assign uo_out[0] = primary_code ^ secondary_code; // L1 Pilot (Tiered)
    assign uo_out[1] = primary_code;
    assign uo_out[2] = secondary_code;
    assign uo_out[3] = secondary_advance; // Strobe for debugging
    assign uo_out[7:4] = 4'b0;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule
