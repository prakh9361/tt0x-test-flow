# Open Road
Yosys — synthesizes Verilog RTL into a gate-level netlist (targeting standard cells).

Place & Route engines (via OpenROAD integrated scripts) take that netlist and physically place standard cells and route interconnects to meet design constraints.

DRC/LVS & Verification — physical design rule checks and layout vs schematic checks are part of the flow (often via tools like Magic/KLayout or other open checks orchestrated by OpenLane).

PDK Support — the SkyWater 130nm PDK is used for Tiny Tapeout runs, so the generated GDS complies with that process.

## Look into the config.json file
