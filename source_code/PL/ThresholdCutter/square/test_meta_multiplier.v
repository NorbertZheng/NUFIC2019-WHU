`timescale 1ns/1ns
module test_meta_multiplier #(
	parameter		OP_WIDTH	=	16
	`define			RES_WIDTH		(OP_WIDTH << 1)
) (

);

	// meta_multiplier signals
	wire [`RES_WIDTH - 1:0] result;
	reg [OP_WIDTH - 1:0] src0, src1;

	initial
		begin
		src0 = {OP_WIDTH{1'b0}};
		src1 = {OP_WIDTH{1'b0}};
		# 100;
		src0 = 16'h1234;
		src1 = 16'h1234;
		# 100;
		src0 = 16'hffff;
		src1 = 16'hffff;
		end

	// meta_multiplier
	meta_multiplier #(
		.OP_WIDTH(OP_WIDTH)
	) m_meta_multiplier (
		// temp useless
		.clk		(			),
		.rst_n		(			),

		.src0		(src0		),
		.src1		(src1		),

		.result		(result		)
	);

endmodule
