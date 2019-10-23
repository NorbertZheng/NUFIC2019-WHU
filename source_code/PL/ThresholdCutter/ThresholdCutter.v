module ThresholdCutte #(
	parameter		SAMPLING_RATE		=	200,				// sampling rate
					PACKAGE_NUM			=	4					// number of package
	`define			WINDOW_DEPTH		(SAMPLING_RATE >> 1)	// window depth
	`define			PACKAGE_BIT_WIDTH	(PACKAGE_NUM << 3)		// package bit-width
) (
	input										clk			,
	input										rst_n		,

	input		[`PACKAGE_BIT_WIDTH - 1:0]		package_i	,	// package write data
	input										package_wen	,	// package write enable signal

	output		[`WINDOW_DEPTH - 1:0]			energy			// energy of package data
);

	

endmodule
