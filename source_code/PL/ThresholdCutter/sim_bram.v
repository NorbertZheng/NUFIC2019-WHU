module sim_bram #(
	parameter		BLOCK_NUM_INDEX		=	6,			// 2 ** 6 == 64 blocks
					BLOCK_DEPTH_INDEX	=	(7 + 2),	// 2 ** 9 == 512( * 32bit(4B))
	`define			BLOCK_INDEX			(BLOCK_NUM_INDEX + BLOCK_DEPTH_INDEX)
					BLOCK_WIDTH			=	32			// 32bit -> 4B
) (
	input								clk			,

	// write
	input								bram_wen	,
	input		[BLOCK_WIDTH - 1:0]		bram_data_i	,
	input		[`BLOCK_INDEX - 1:0]	bram_waddr	,

	// read
	input		[`BLOCK_INDEX - 1:0]	bram_raddr	,
	output		[BLOCK_WIDTH - 1:0]		bram_data_o	
);

	reg [BLOCK_WIDTH - 1:0] sim_bram_data[`BLOCK_INDEX - 1:0];

	always@ (posedge clk)
		begin
		if (bram_wen)
			begin
			sim_bram_data[bram_waddr] <= bram_data_i;
			end
		end

	assign bram_data_o = sim_bram_data[bram_raddr];

endmodule
