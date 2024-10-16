`ifdef RTL
    `define CYCLE_TIME 6.0
`endif
`ifdef GATE
    `define CYCLE_TIME 6.0
`endif

module PATTERN(
    // Output signals
    clk,
	rst_n,
	in_valid,
    in_data, 
	in_mode,
    // Input signals
    out_valid, 
	out_data
);

// ========================================
// Input & Output
// ========================================
output reg clk, rst_n, in_valid;
output reg [8:0] in_mode;
output reg [14:0] in_data;

input out_valid;
input [206:0] out_data;



endmodule