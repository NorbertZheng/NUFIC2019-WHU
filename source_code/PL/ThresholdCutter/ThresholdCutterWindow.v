module ThresholdCutterWindow #(
	parameter		// parameter for window
					WINDOW_DEPTH_INDEX		=	7,				// support up to 128 windows
					WINDOW_DEPTH			=	100,			// 100 windows
					WINDOW_WIDTH			=	32,				// 32-bit window
					THRESHOLD				=	32'h0010_0000,	// threshold
					BLOCK_NUM_INDEX			=	6,				// 2 ** 6 == 64 blocks
	`define			BLOCK_DEPTH				(WINDOW_DEPTH << 2)	// 400 package per data
	`define			BLOCK_DEPTH_INDEX		(WINDOW_DEPTH_INDEX + 2)		// 15 -> 2 ** 15 * 2 ** 2(B) -> 128KB, not related with BLOCK_DEPTH so much
					// parameter for package
					A_OFFSET				=	2,				// A's offset
	`define			A_BIT_OFFSET			(A_OFFSET << 3)
					// parameter for square
					SQUARE_SRC_DATA_WIDTH	=	16				// square src data width
	`define			SQUARE_RES_DATA_WIDTH	(SRC_DATA_WIDTH << 1)
) (
	input								clk,
	input								rst_n,

	input		[WINDOW_WIDTH - 1:0]	data_i,
	input								data_wen,

	output		[WINDOW_DEPTH - 1:0]	flag_o
);

	// bram signals
	reg bram_wen;
	reg [WINDOW_WIDTH - 1:0] bram_data_i;

	// inner signals
	integer j;
	reg [WINDOW_WIDTH - 1:0] window_data[WINDOW_DEPTH - 1:0];
	reg [WINDOW_DEPTH_INDEX - 1:0] ptr;							// point to next loc to write
	// reg [WINDOW_DEPTH_INDEX - 1:0] ptrPlus1;					// next to write, restore it!!!
	reg [`BLOCK_DEPTH_INDEX - 1:0] block_ptr;
	reg [BLOCK_NUM_INDEX - 1:0] block_no;
	wire break_flag = ~(|flag_o);								// all less than threshold
	reg window_data_fulfill;									// when first fulfill it, set to 1'b1, and never change
	reg [WINDOW_DEPTH_INDEX - 1:0] valid_cnt;					// when break_flag, set to 0, and set window_data_fulfill to 0
	reg data_wen_delay;

	// energy flag_o
	wire [`SQUARE_RES_DATA_WIDTH:0] squareSum[WINDOW_DEPTH - 1:0];
	wire [WINDOW_DEPTH - 1:0] squareSumCo;					// co signal by squareSum
	wire [`SQUARE_RES_DATA_WIDTH:0] tempSquareSum[WINDOW_DEPTH - 1:0];
	wire [WINDOW_DEPTH - 1:0] tempSquareSumCo;					// co signal by tempSquareSum
	wire [`SQUARE_RES_DATA_WIDTH:0] AxSquare[WINDOW_DEPTH - 1:0];
	wire [`SQUARE_RES_DATA_WIDTH:0] AySquare[WINDOW_DEPTH - 1:0];
	wire [`SQUARE_RES_DATA_WIDTH:0] AzSquare[WINDOW_DEPTH - 1:0];
	genvar i;
	generate
	for (i = 0; i < WINDOW_DEPTH; i = i + 1)
		begin
		// AxSquare
		square #(
			.SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH)
		) m_AxSquare (
			// temp useless
			.clk		(clk													),
			.rst_n		(rst_n													),

			// square src
			.src0		(window_data[i][`A_BIT_OFFSET + 7:`A_BIT_OFFSET + 6]	),
			.src1		(window_data[i][`A_BIT_OFFSET + 7:`A_BIT_OFFSET + 6]	),

			// square res
			.res		(AxSquare[i]											)
		);
		// AySquare
		square #(
			.SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH)
		) m_AySquare (
			// temp useless
			.clk		(clk													),
			.rst_n		(rst_n													),

			// square src
			.src0		(window_data[i][`A_BIT_OFFSET + 5:`A_BIT_OFFSET + 4]	),
			.src1		(window_data[i][`A_BIT_OFFSET + 5:`A_BIT_OFFSET + 4]	),

			// square res
			.res		(AySquare[i]											)
		);
		// AzSquare
		square #(
			.SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH)
		) m_AzSquare (
			// temp useless
			.clk		(clk													),
			.rst_n		(rst_n													),

			// square src
			.src0		(window_data[i][`A_BIT_OFFSET + 3:`A_BIT_OFFSET + 2]	),
			.src1		(window_data[i][`A_BIT_OFFSET + 3:`A_BIT_OFFSET + 2]	),

			// square res
			.res		(AzSquare[i]											)
		);
		// tempSquareSum
		cla32 m_tempSquareSum(
			.a			(AxSquare[i]											),
			.b			(AySquare[i]											),
			.ci			(1'b0													),
			.s			(tempSquareSum[i]										),
			.co			(tempSquareSumCo[i]										)
		);
		// squareSum
		cla32 m_tempSquareSum(
			.a			(tempSquareSum[i]										),
			.b			(AzSquare[i]											),
			.ci			(1'b0													),
			.s			(squareSum[i]											),
			.co			(squareSumCo[i]											)
		);
		// energy flag_o
		assign flag_o[i] = (SquareSumCo[i] | tempSquareSumCo[i] | (squareSum >= THRESHOLD));
		end
	endgenerate

	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			for (j = 0; j < WINDOW_DEPTH; j = j + 1)
				begin
				// inner signals
				window_data[j] <= {WINDOW_WIDTH{1'b0}};
				ptr <= {WINDOW_DEPTH_INDEX{1'b0}};
				// ptrPlus1 <= 1;
				block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};		// init as 0xffff, always point to the last write unit
				block_no <= {BLOCK_NUM_INDEX{1'b0}};
				window_data_fulfill <= 1'b0;
				valid_cnt <= {WINDOW_DEPTH_INDEX{1'b0}};
				data_wen_delay <= 1'b0;
				// for bram
				bram_wen <= 1'b0;
				bram_data_i <= {WINDOW_WIDTH{1'b0}};
				end
			end
		else
			begin
			data_wen_delay <= data_wen;
			if (data_wen)		// write data
				begin
				// inner signals
				window_data[ptr] <= data_i;
				valid_cnt <= valid_cnt + 1'b1;
				if (ptr == WINDOW_DEPTH - 1)		ptr <= {WINDOW_DEPTH_INDEX{1'b0}};			// back up
				else								ptr <= ptr + 1'b1;
				/*if (ptrPlus1 == WINDOW_DEPTH - 1)	ptrPlus1 <= {WINDOW_DEPTH_INDEX{1'b0}};			// back up
				else								ptrPlus1 <= ptrPlus1 + 1'b1;*/
				if (valid_cnt == WINDOW_DEPTH - 1)					// we fulfill the window_data
					begin
					window_data_fulfill <= 1'b1;
					end
				end
			else
				begin
				if (break_flag)	// to break data stream
					begin
					if (block_ptr < BLOCK_DEPTH - 1)			// current block is not full, fill it with 32'b0
						begin
						// inner signals, window_data & ptr do not change
						block_ptr <= block_ptr + 1'b1;
						// for bram
						bram_wen <= 1'b1;
						bram_data_i <= 32'b0;
						end
					else if (block_ptr == BLOCK_DEPTH - 1)		// fill complete!
						begin
						// inner signals, window_data & ptr do not change, block_ptr must not change, left it to data_wen
						block_no <= block_no + 1'b1;			// next block
						block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};
						valid_cnt <= {WINDOW_DEPTH{1'b0}};
						window_data_fulfill <= 1'b0;
						// for bram
						bram_wen <= 1'b0;						// not write bram
						bram_data_i <= 32'b0;
						end
					else										// data is not valid
						begin
						// inner signals
						block_ptr = {`BLOCK_DEPTH_INDEX{1'b1}};
						valid_cnt <= {WINDOW_DEPTH{1'b0}};
						window_data_fulfill <= 1'b0;
						// for bram
						bram_wen <= 1'b0;						// not write bram
						bram_data_i <= 32'b0;
					end
				else											// not in break, data is valid or is trying to be valid
					begin
					if (window_data_fulfill)					// data is valid
						begin
						if (data_wen_delay)						// ensure 1-period write, avoid double-write
							begin
							if (block_ptr < BLOCK_DEPTH - 1 || block_ptr == {`BLOCK_DEPTH_INDEX{1'b1}})		// current block is not full, even empty
								begin
								// inner signals, window_data & ptr do not change
								block_ptr <= block_ptr + 1'b1;
								// for bram
								bram_wen <= 1'b1;
								bram_data_i <= window_data[ptr];
								end
							else if (block_ptr == BLOCK_DEPTH - 1)	// one block is full (should not happen)
								begin
								// inner signals
								block_no <= block_no + 1'b1;		// next block
								block_ptr <= {`BLOCK_DEPTH_INDEX{1'b0}};
								// for bram
								bram_wen <= 1'b1;
								bram_data_i <= window_data[ptr];
								end
							end
						end
					else										// data is trying to be valid, do nothing(wait the last to be valid)
						begin
						// do nothing
						end
					end
				end
			end
		end

	`ifdef sim_window
	sim_bram #(
		.BLOCK_NUM_INDEX(BLOCK_NUM_INDEX),			// 2 ** 6 == 64 blocks
		.BLOCK_DEPTH_INDEX(`BLOCK_DEPTH_INDEX),	// 2 ** 9 == 512( * 32bit(4B))
		.BLOCK_WIDTH(WINDOW_WIDTH)			// 32bit -> 4B
	) m_sim_bram (
		.clk			(clk					),

		// write
		.bram_wen		(bram_wen				),
		.bram_data_i	(bram_data_i			),
		.bram_waddr		({block_no, block_ptr}	),

		// read
		.bram_raddr		(						),
		.bram_data_o	(						)
	);
	`endif

endmodule
