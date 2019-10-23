module square #(
	parameter		SRC_DATA_WIDTH		=	16
	`define			RES_DATA_WIDTH		(SRC_DATA_WIDTH << 1)
) (
	// temp useless
	input									clk			,
	input									rst_n		,

	// square src
	input		[SRC_DATA_WIDTH - 1:0]		src0		,
	input		[SRC_DATA_WIDTH - 1:0]		src1		,

	// square res
	output		[`RES_DATA_WIDTH - 1:0]		res
);

	// meta_multiplier signals
	wire [SRC_DATA_WIDTH - 1:0] src0_p = src0[SRC_DATA_WIDTH - 1] ? (~src0 + 1) : src0;
	wire [SRC_DATA_WIDTH - 1:0] src1_p = src1[SRC_DATA_WIDTH - 1] ? (~src1 + 1) : src1;

	// assign res = src0 * src1;

	// meta_multiplier
	meta_multiplier # (
		.OP_WIDTH(SRC_DATA_WIDTH)
	) (
		// temp useless
		.clk		(clk	),
		.rst_n		(rst_n	),

		.src0		(src0_p	),
		.src1		(src1_p	),

		.result		(res	)
	);
	/*meta_multiplier m_multiplier(
		.CLK(clk),
		.A(src0),
		.B(src1),
		.P(res)
	);*/

endmodule
