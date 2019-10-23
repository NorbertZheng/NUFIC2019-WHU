module meta_multiplier #(
	parameter		OP_WIDTH	=	16
	`define			RES_WIDTH		(OP_WIDTH << 1)
) (
	// temp useless
	input								clk			,
	input								rst_n		,

	input		[OP_WIDTH - 1:0]		src0		,
	input		[OP_WIDTH - 1:0]		src1		,

	output		[`RES_WIDTH - 1:0]		result		
);

	wire [`RES_WIDTH - 1:0] src0src1[OP_WIDTH - 1:0];
	wire [`RES_WIDTH - 1:0] src0src1_2[(OP_WIDTH >> 1) - 1:0];
	wire [`RES_WIDTH - 1:0] src0src1_3[(OP_WIDTH >> 2) - 1:0];
	wire [`RES_WIDTH - 1:0] src0src1_4[(OP_WIDTH >> 3) - 1:0];
	genvar i;
	generate
	// 16 elements
	for (i = 0; i < OP_WIDTH; i = i + 1)
		begin
		assign src0src1[i] = (src1[i] ? src0 : 0) << i;
		end
	// 8 elements
	for (i = 0; i < (OP_WIDTH >> 1); i = i + 1)
		begin
		cla32 m_cal32_2(
			.a		(src0src1[(i << 1)]),
			.b		(src0src1[(i << 1) + 1]),
			.ci		(1'b0),
			.s		(src0src1_2[i]),
			.co		()
		);
		end
	// 4 elements
	for (i = 0; i < (OP_WIDTH >> 2); i = i + 1)
		begin
		cla32 m_cal32_3(
			.a		(src0src1_2[(i << 1)]),
			.b		(src0src1_2[(i << 1) + 1]),
			.ci		(1'b0),
			.s		(src0src1_3[i]),
			.co		()
		);
		end
	// 2 elements
	for (i = 0; i < (OP_WIDTH >> 3); i = i + 1)
		begin
		cla32 m_cal32_4(
			.a		(src0src1_3[(i << 1)]),
			.b		(src0src1_3[(i << 1) + 1]),
			.ci		(1'b0),
			.s		(src0src1_4[i]),
			.co		()
		);
		end
	// result
	cla32 m_cal32_5(
		.a		(src0src1_4[0]),
		.b		(src0src1_4[1]),
		.ci		(1'b0),
		.s		(result),
		.co		()
	);
	endgenerate

endmodule
