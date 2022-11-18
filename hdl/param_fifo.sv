module param_fifo #(
	parameter int WIDTH_DATA = 0                 ,
	parameter int NUMWORDS   = 0                 ,
	parameter bit REG_OUT    = 0                 ,
	parameter int _WIDTH_UW  = $clog2(NUMWORDS+1)
) (
	input  logic                  clk    ,
	input  logic                  rst    ,

	input  logic                  wr_en  ,
	input  logic [WIDTH_DATA-1:0] wr_data,

	input  logic                  rd_en  ,
	output logic [WIDTH_DATA-1:0] rd_data,

	output logic                  full   ,
	output logic                  empty  ,
	output logic [ _WIDTH_UW-1:0] usedw
);

wire wr_en_ram = wr_en && !full;
wire rd_en_ram = rd_en && !empty;

always_ff @(posedge clk or posedge rst)
	if (rst)
		usedw <= '0;
	else
		usedw <= usedw + wr_en_ram - rd_en_ram;

assign empty = usedw == '0;
assign full  = usedw >= NUMWORDS;

logic [$clog2(NUMWORDS)-1:0] wr_addr, rd_addr;

always_ff @(posedge clk or posedge rst)
	if (rst)
		wr_addr <= '0;
	else if (wr_en_ram)
		wr_addr <= wr_addr == NUMWORDS-1 ? '0 : wr_addr + 1'b1;

always_ff @(posedge clk or posedge rst)
	if (rst)
		rd_addr <= '0;
	else if (rd_en_ram)
		rd_addr <= rd_addr == NUMWORDS-1 ? '0 : rd_addr + 1'b1;

logic [WIDTH_DATA-1:0] rd_data_async, rd_data_reg;

param_ram #(.WIDTH_DATA(WIDTH_DATA), .NUMWORDS(NUMWORDS)) i_param_ram (
	.clk    (clk          ),
	.wr_en  (wr_en_ram    ),
	.wr_addr(wr_addr      ),
	.wr_data(wr_data      ),
	.rd_en  (rd_en_ram    ),
	.rd_addr(rd_addr      ),
	.rd_data(rd_data_async)
);

always_ff @(posedge clk or posedge rst)
	if (rst)
		rd_data_reg <= '0;
	else
		rd_data_reg <= rd_data_async;

assign rd_data = REG_OUT ? rd_data_reg : rd_data_async;

endmodule
