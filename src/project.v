`default_nettype none

module tt_um_navic_pilot_gen (
    input  wire [7:0] ui_in,    // Input: ui_in[2:0] = PRN Select
    input  wire [7:0] uio_in,   // IOs: Input path (Unused)
    output wire [7:0] uo_out,   // Output: [0]=Pilot, [1]=Pri, [2]=Sec, [3]=Epoch
    output wire [7:0] uio_out,  // IOs: Output path (Debug/Status)
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (Active Low)
);

    // --- 1. Signal Declarations ---
    wire reset = !rst_n;
    wire [2:0] prn_selector = ui_in[2:0];

    // Initial Condition Registers
    reg [54:0] P_R0_INIT;
    reg [54:0] P_R1_INIT;
    reg [4:0]  P_C_INIT;
    reg [9:0]  S_R0_INIT;
    reg [9:0]  S_R1_INIT;

    // Shift Registers
    reg [54:0] p_r0, p_r1;
    reg [4:0]  p_c;
    reg [9:0]  s_r0, s_r1;
    
    // Counters
    reg [13:0] chip_count; // Max 10230
    reg [10:0] sec_count;  // Max 1800

    // --- 2. PRN Configuration Table ---
    // Values transcribed from user uploaded Table 8 (Primary) and Table 9 (Overlay)
    
    always @(*) begin
        case (prn_selector)
            3'd1: begin // PRN 1
                P_R0_INIT = 55'o0227743641272102303;
                P_R1_INIT = 55'o1667217344450257245;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b0110111011;
                S_R1_INIT = 10'b0100110000;
            end 
            3'd2: begin // PRN 2
                P_R0_INIT = 55'o0603070242564637717;
                P_R1_INIT = 55'o0300642746017221737;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b0111101000;
                S_R1_INIT = 10'b0110000010;
            end
            3'd3: begin // PRN 3
                P_R0_INIT = 55'o0746325144437416120;
                P_R1_INIT = 55'o0474006332201753645;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b1100000001;
                S_R1_INIT = 10'b1110010001;
            end
            3'd4: begin // PRN 4
                P_R0_INIT = 55'o0023763714573206044;
                P_R1_INIT = 55'o0613606702460402137;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b0110110110;
                S_R1_INIT = 10'b0101110011;
            end 
            3'd5: begin // PRN 10
                P_R0_INIT = 55'o0013727517464264567;
                P_R1_INIT = 55'o1116277147142260461;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b1000011010;
                S_R1_INIT = 10'b0100010101;
            end
            3'd6: begin // PRN 11
                P_R0_INIT = 55'o0663351450332761127;
                P_R1_INIT = 55'o0152604753526345370;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b0001001001;
                S_R1_INIT = 10'b1100000100;
            end
            3'd7: begin // PRN 12
                P_R0_INIT = 55'o1450710073416110356;
                P_R1_INIT = 55'o1110300535412261305;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b0110101011;
                S_R1_INIT = 10'b0111011110;
            end 
            3'd0: begin // PRN 13
                P_R0_INIT = 55'o1716542347100366110;
                P_R1_INIT = 55'o1046105227571557243;
                P_C_INIT  = 5'b01000;
                S_R0_INIT = 10'b0101110000;
                S_R1_INIT = 10'b1001110011;
            end
            default: begin // Default to PRN 10 (Safety)
                P_R0_INIT = 55'o0013727517464264567;
                P_R1_INIT = 55'o1116277147142260461;
                P_C_INIT  = 5'b00000;
                S_R0_INIT = 10'b1000011010;
                S_R1_INIT = 10'b0100010101;
            end
        endcase
    end

    // --- 3. Combinational Feedback Logic ---

    // Primary Code Feedback (IZ4)
    // Note: R0[54] is Input, R0[0] is Output
    wire p_r0_fb = p_r0[50] ^ p_r0[45] ^ p_r0[40] ^ p_r0[20] ^ p_r0[10] ^ p_r0[5] ^ p_r0[0];
    
    wire sigma_2a = (p_r0[50]^p_r0[45]^p_r0[40]) & (p_r0[20]^p_r0[10]^p_r0[5]^p_r0[0]);
    wire sigma_2b = ((p_r0[50]^p_r0[45])&p_r0[40]) ^ ((p_r0[20]^p_r0[10])&(p_r0[5]^p_r0[0]));
    wire sigma_2c = (p_r0[50] & p_r0[45]) ^ (p_r0[20] & p_r0[10]) ^ (p_r0[5] & p_r0[0]);
    wire sigma_2  = sigma_2a ^ sigma_2b ^ sigma_2c;

    wire p_r1a = sigma_2 ^ (p_r0[40]^p_r0[35]^p_r0[30]^p_r0[25]^p_r0[15]^p_r0[0]);
    wire p_r1b = p_r1[50]^p_r1[45]^p_r1[40]^p_r1[20]^p_r1[10]^p_r1[5]^p_r1[0];
    wire p_r1_fb = p_r1a ^ p_r1b;

    wire p_c_fb = p_c[0]; // Pure Cycling
    wire primary_code = p_c[0] ^ p_r1[0];

    // Secondary Code Feedback (Overlay)
    wire s_r0_fb = s_r0[5] ^ s_r0[2] ^ s_r0[1] ^ s_r0[0];

    wire s_sigma_2a = (s_r0[5] ^ s_r0[2]) & (s_r0[1] ^ s_r0[0]);
    wire s_sigma_2b = (s_r0[5] & s_r0[2]) ^ (s_r0[1] & s_r0[0]);
    wire s_sigma_2  = s_sigma_2a ^ s_sigma_2b;
    
    wire s_r1a = s_sigma_2 ^ s_r0[6] ^ s_r0[3] ^ s_r0[2] ^ s_r0[0];
    wire s_r1b = s_r1[5] ^ s_r1[2] ^ s_r1[1] ^ s_r1[0];
    wire s_r1_fb = s_r1a ^ s_r1b;

    wire secondary_code = s_r1[0];

    // --- 4. State Machine & Registers ---

    // Control Signals
    wire primary_reset_condition = (chip_count == 10229);
    wire secondary_advance = primary_reset_condition; // Clock secondary every 10230 pri chips

    always @(posedge clk) begin
        if (reset) begin
            p_r0 <= P_R0_INIT;
            p_r1 <= P_R1_INIT;
            p_c  <= P_C_INIT;
            chip_count <= 0;

            s_r0 <= S_R0_INIT;
            s_r1 <= S_R1_INIT;
            sec_count <= 0;
        end else if (ena) begin
            
            // Primary Logic (Reset or Shift)
            if (primary_reset_condition) begin
                // Re-load initial conditions at end of epoch
                p_r0 <= P_R0_INIT;
                p_r1 <= P_R1_INIT;
                p_c  <= P_C_INIT;
                chip_count <= 0;
            end else begin
                // Shift: Input at MSB (54), Drop LSB (0)
                p_r0 <= {p_r0_fb, p_r0[54:1]};
                p_r1 <= {p_r1_fb, p_r1[54:1]};
                p_c  <= {p_c_fb,  p_c[4:1]};
                chip_count <= chip_count + 1;
            end

            // Secondary Logic
            if (secondary_advance) begin
                if (sec_count == 1799) begin
                    // Secondary Short Cycle Reset
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

    // --- 5. Output Assignments ---
    assign uo_out[0] = primary_code ^ secondary_code; // PILOT SIGNAL
    assign uo_out[1] = primary_code;                  // Debug: Raw Primary
    assign uo_out[2] = secondary_code;                // Debug: Raw Secondary
    assign uo_out[3] = secondary_advance;             // Debug: Epoch Pulse (approx 10ms)
    assign uo_out[7:4] = 4'b0;                        // Unused outputs low

    // Tie off unused IOs
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b11111111; // Enable outputs

endmodule
