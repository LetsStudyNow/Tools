module param_ram #(
	parameter WIDTH_DATA = 0,
	parameter NUMWORDS   = 0
) (
	input  logic                        clk    ,

	input  logic                        wr_en  ,
	input  logic [$clog2(NUMWORDS)-1:0] wr_addr,
	input  logic [      WIDTH_DATA-1:0] wr_data,

	input  logic                        rd_en  ,
	input  logic [$clog2(NUMWORDS)-1:0] rd_addr,
	output logic [      WIDTH_DATA-1:0] rd_data
);

logic [WIDTH_DATA-1:0] mem [NUMWORDS];

always_ff @(posedge clk)
	if (wr_en)
		mem[wr_addr] <= wr_data;

always_ff @(posedge clk)
	if (rd_en)
		rd_data <= mem[rd_addr];

endmodule
