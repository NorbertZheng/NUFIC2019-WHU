`timescale 1ns/1ns
module ThresholdCutterWindow #(
	parameter		// enable simulation
					SIM_ENABLE				=	0,				// enable simulation
					// parameter for window
					WINDOW_DEPTH_INDEX		=	7,				// support up to 128 windows
					WINDOW_DEPTH			=	100,			// 100 windows
					WINDOW_WIDTH			=	(32 << 3),		// 32B window
					THRESHOLD				=	32'h0010_0000,	// threshold
					BLOCK_NUM_INDEX			=	4,				// 2 ** 6 == 64 blocks		// 16
	`define			BLOCK_DEPTH				(WINDOW_DEPTH << 2)	// 400 package per data
	`define			BLOCK_DEPTH_INDEX		(WINDOW_DEPTH_INDEX + 2)		// 15 -> 2 ** 15 * 2 ** 2(B) -> 128KB, not related with BLOCK_DEPTH so much
					// parameter for package
					A_OFFSET				=	2,				// A's offset
	`define			A_BYTE_OFFSET			(A_OFFSET << 3)
	`define			A_BIT_OFFSET			(`A_BYTE_OFFSET << 3)
					// parameter for square
					SQUARE_SRC_DATA_WIDTH	=	16,				// square src data width
	`ifndef			SQUARE_RES_DATA_WIDTH
	`define			SQUARE_RES_DATA_WIDTH	(SQUARE_SRC_DATA_WIDTH << 1)
	`endif
					// parameter for preset-sequence
					PRESET_SEQUENCE			=	128'h00_01_02_03_04_05_06_07_08_09_00_01_02_03_04_05
) (
	input								clk,
	input								rst_n,

	input		[WINDOW_WIDTH:0]		data_i,
	input								data_wen,

	output		[WINDOW_DEPTH - 1:0]	flag_o,

	// AXI RAM signals
	// ram safe access
	output								rsta_busy,
	output								rstb_busy,

	// AXI read control signals
	input		[3:0]					s_axi_arid,
	input		[31:0]					s_axi_araddr,
	input		[7:0]					s_axi_arlen,
	input		[2:0]					s_axi_arsize,
	input		[1:0]					s_axi_arburst,
	input								s_axi_arvalid,
	output								s_axi_arready,

	// AXI read data signals
	output		[3:0]					s_axi_rid,
	output		[255:0]					s_axi_rdata,
	output		[1:0]					s_axi_rresp,
	output								s_axi_rlast,
	output								s_axi_rvalid,
	input								s_axi_rready
);

	// bram signals
	reg bram_wen;
	reg [WINDOW_WIDTH - 1:0] bram_data_i;

	// dram signals
	reg dram_wen;
	reg [7:0] dram_data_i;

	// axi_bram signals
	wire s_aclk, s_aresetn;
	wire s_axi_awvalid, s_axi_awready;
	wire [1:0] s_axi_awburst;
	wire [2:0] s_axi_awsize;
	wire [3:0] s_axi_awid;
	wire [7:0] s_axi_awlen;
	wire [31:0] s_axi_awaddr;
	wire s_axi_wlast, s_axi_wvalid, s_axi_wready;
	wire [31:0] s_axi_wstrb;
	wire [255:0] s_axi_wdata;
	wire s_axi_bvalid, s_axi_bready;
	wire [1:0] s_axi_bresp;
	wire [3:0] s_axi_bid;

	// inner signals
	integer j;
	reg [WINDOW_WIDTH - 1:0] window_data[WINDOW_DEPTH - 1:0];
	reg [WINDOW_DEPTH - 1:0] window_tag;
	reg [WINDOW_DEPTH_INDEX - 1:0] ptr;							// point to next loc to write
	// reg [WINDOW_DEPTH_INDEX - 1:0] ptrPlus1;					// next to write, restore it!!!
	reg [`BLOCK_DEPTH_INDEX - 1:0] block_ptr;
	reg [BLOCK_NUM_INDEX - 1:0] block_no;
	wire break_flag = ~(|flag_o);								// all less than threshold
	reg window_data_fulfill;									// when first fulfill it, set to 1'b1, and never change
	reg [WINDOW_DEPTH_INDEX - 1:0] valid_cnt;					// when break_flag, set to 0, and set window_data_fulfill to 0
	reg data_wen_delay;
	// reg [127:0] preset_sequence = PRESET_SEQUENCE;
	reg [63:0] preset_sequence = PRESET_SEQUENCE;
	reg write_tag;
	// for debug
	(* mark_debug = "true" *)wire [WINDOW_WIDTH - 1:0] debug_window_data[WINDOW_DEPTH - 1:0];
	genvar k;
	generate
	for (k = 0; k < WINDOW_DEPTH; k = k + 1)
		begin
		assign debug_window_data[k] = window_data[k];
		end
	endgenerate

	/*// energy flag_o
	wire [`SQUARE_RES_DATA_WIDTH - 1:0] squareSum[WINDOW_DEPTH - 1:0];
	wire [WINDOW_DEPTH - 1:0] squareSumCo;					// co signal by squareSum
	wire [`SQUARE_RES_DATA_WIDTH - 1:0] tempSquareSum[WINDOW_DEPTH - 1:0];
	wire [WINDOW_DEPTH - 1:0] tempSquareSumCo;					// co signal by tempSquareSum
	wire [`SQUARE_RES_DATA_WIDTH - 1:0] AxSquare[WINDOW_DEPTH - 1:0];
	wire [`SQUARE_RES_DATA_WIDTH - 1:0] AySquare[WINDOW_DEPTH - 1:0];
	wire [`SQUARE_RES_DATA_WIDTH - 1:0] AzSquare[WINDOW_DEPTH - 1:0];
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
			.src0		({window_data[i][`A_BIT_OFFSET + 48 + 7:`A_BIT_OFFSET + 48 + 0], window_data[i][`A_BIT_OFFSET + 56 + 7:`A_BIT_OFFSET + 56 + 0]}	),
			.src1		({window_data[i][`A_BIT_OFFSET + 48 + 7:`A_BIT_OFFSET + 48 + 0], window_data[i][`A_BIT_OFFSET + 56 + 7:`A_BIT_OFFSET + 56 + 0]}	),

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
			.src0		({window_data[i][`A_BIT_OFFSET + 32 + 7:`A_BIT_OFFSET + 32 + 0], window_data[i][`A_BIT_OFFSET + 40 + 7:`A_BIT_OFFSET + 40 + 0]}	),
			.src1		({window_data[i][`A_BIT_OFFSET + 32 + 7:`A_BIT_OFFSET + 32 + 0], window_data[i][`A_BIT_OFFSET + 40 + 7:`A_BIT_OFFSET + 40 + 0]}	),

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
			.src0		({window_data[i][`A_BIT_OFFSET + 16 + 7:`A_BIT_OFFSET + 16 + 0], window_data[i][`A_BIT_OFFSET + 24 + 7:`A_BIT_OFFSET + 24 + 0]}	),
			.src1		({window_data[i][`A_BIT_OFFSET + 16 + 7:`A_BIT_OFFSET + 16 + 0], window_data[i][`A_BIT_OFFSET + 24 + 7:`A_BIT_OFFSET + 24 + 0]}	),

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
		cla32 m_squareSum(
			.a			(tempSquareSum[i]										),
			.b			(AzSquare[i]											),
			.ci			(1'b0													),
			.s			(squareSum[i]											),
			.co			(squareSumCo[i]											)
		);
		// energy flag_o
		assign flag_o[i] = (squareSumCo[i] | tempSquareSumCo[i] | (squareSum[i] >= THRESHOLD));
		end
	endgenerate*/
	assign flag_o = window_tag;

	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			for (j = 0; j < WINDOW_DEPTH; j = j + 1)
				begin
				// inner signals
				window_data[j] <= {WINDOW_WIDTH{1'b0}};
				end
			// inner signals
			window_tag <= {WINDOW_DEPTH{1'b0}};
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
			// for dram
			write_tag <= 1'b0;
			// dram_wen <= 1'b0;
			// dram_data_i <= 8'b0;
			end
		else
			begin
			data_wen_delay <= data_wen;
			if (data_wen)		// write data
				begin
				// inner signals
				window_data[ptr] <= data_i[WINDOW_WIDTH:1];
				window_tag[ptr] <= data_i[0];
				valid_cnt <= valid_cnt + 1'b1;
				if (ptr == WINDOW_DEPTH - 1)		ptr <= {WINDOW_DEPTH_INDEX{1'b0}};			// back up
				else								ptr <= ptr + 1'b1;
				/*if (ptrPlus1 == WINDOW_DEPTH - 1)	ptrPlus1 <= {WINDOW_DEPTH_INDEX{1'b0}};			// back up
				else								ptrPlus1 <= ptrPlus1 + 1'b1;*/
				if (valid_cnt == WINDOW_DEPTH - 1)					// we fulfill the window_data
					begin
					window_data_fulfill <= 1'b1;
					end
				// for dram
				write_tag <= 1'b0;
				// dram_wen <= 1'b0;
				// dram_data_i <= 8'b0;
				end
			else
				begin
				if (write_tag)								// means we already get the end
					begin
					// inner signals, window_data & ptr do not change
					block_ptr <= block_ptr + 1'b1;
					// for bram
					bram_wen <= 1'b1;
					bram_data_i <= {248'h0, preset_sequence[block_no[2:0]]};			/////////////////////////////////////////////////
					// for dram
					write_tag <= 1'b0;
					end
				else if (break_flag)	// to break data stream
					begin
					if (block_ptr < `BLOCK_DEPTH - 1)			// current block is not full, fill it with 32'b0
						begin
						// inner signals, window_data & ptr do not change
						block_ptr <= block_ptr + 1'b1;
						valid_cnt <= {WINDOW_DEPTH{1'b0}};
						window_data_fulfill <= 1'b0;
						// for bram
						bram_wen <= 1'b1;
						bram_data_i <= 32'b0;
						// for dram
						if (block_ptr == `BLOCK_DEPTH - 2)		write_tag <= 1'b1;						// prepare to write the last
						else									write_tag <= 1'b0;
						// dram_wen <= 1'b0;
						// dram_data_i <= 8'b0;
						end
					else if (block_ptr == `BLOCK_DEPTH)		// fill complete!
						begin
						// inner signals, window_data & ptr do not change, block_ptr must not change, left it to data_wen
						block_no <= block_no + 1'b1;			// next block
						block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};
						valid_cnt <= {WINDOW_DEPTH{1'b0}};
						window_data_fulfill <= 1'b0;
						// for bram
						bram_wen <= 1'b0;						// not write bram
						bram_data_i <= 32'b0;
						// for dram
						write_tag <= 1'b0;
						// dram_wen <= 1'b1;
						// dram_data_i <= preset_sequence[block_no[3:0]];
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
						// for dram
						write_tag <= 1'b0;
						// dram_wen <= 1'b0;
						// dram_data_i <= 8'b0;
						end
					end
				else											// not in break, data is valid or is trying to be valid
					begin
					if (window_data_fulfill)					// data is valid
						begin
						if (data_wen_delay)						// ensure 1-period write, avoid double-write
							begin
							if (block_ptr < `BLOCK_DEPTH - 1 || block_ptr == {`BLOCK_DEPTH_INDEX{1'b1}})		// current block is not full, even empty
								begin
								// inner signals, window_data & ptr do not change
								block_ptr <= block_ptr + 1'b1;
								// for bram
								bram_wen <= 1'b1;
								bram_data_i <= window_data[ptr];
								// for dram
								if (block_ptr == `BLOCK_DEPTH - 2)		write_tag <= 1'b1;						// prepare to write the last
								else									write_tag <= 1'b0;
								// dram_wen <= 1'b0;
								// dram_data_i <= 8'b0;
								end
							else if (block_ptr == `BLOCK_DEPTH)		// one block is full (should not happen)
								begin
								// inner signals
								block_no <= block_no + 1'b1;		// next block
								block_ptr <= {`BLOCK_DEPTH_INDEX{1'b0}};
								// for bram
								bram_wen <= 1'b1;
								bram_data_i <= window_data[ptr];
								// for dram
								write_tag <= 1'b0;
								// dram_wen <= 1'b1;
								// dram_data_i <= preset_sequence[block_no[3:0]];
								end
							end
						else
							begin
							// for bram
							bram_wen <= 1'b0;
							// for dram
							dram_wen <= 1'b0;
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

	generate
	if (SIM_ENABLE)
		begin
		// sim_bram
		sim_bram #(
			.BLOCK_NUM_INDEX(BLOCK_NUM_INDEX),			// 2 ** 6 == 64 blocks
			.BLOCK_DEPTH_INDEX(`BLOCK_DEPTH_INDEX),	// 2 ** 9 == 512( * 32bit(4B))
			.BLOCK_WIDTH(WINDOW_WIDTH)			// 32 x 8bit -> 32B
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
		/*// sim_dram
		sim_bram #(
			.BLOCK_NUM_INDEX(BLOCK_NUM_INDEX),			// 2 ** 6 == 64 blocks		// 16
			.BLOCK_DEPTH_INDEX(0),						// 2 ** 0 == 1
			.BLOCK_WIDTH(8)								// 8bit
		) m_sim_dram (
			.clk			(clk					),

			// write
			.bram_wen		(dram_wen				),
			.bram_data_i	(dram_data_i			),
			.bram_waddr		(block_no				),

			// read
			.bram_raddr		(						),
			.bram_data_o	(						)
		);*/
		end
	else
		begin
		// bram
		bram m_bram(
			// output safe access
			.rsta_busy		(rsta_busy				),
			.rstb_busy		(rstb_busy				),

			// clk & rst_n
			.s_aclk			(s_aclk					),
			.s_aresetn		(s_aresetn				),

			// AXI write control signals
			.s_axi_awid		(s_axi_awid				),
			.s_axi_awaddr	(s_axi_awaddr			),
			.s_axi_awlen	(s_axi_awlen			),
			.s_axi_awsize	(s_axi_awsize			),
			.s_axi_awburst	(s_axi_awburst			),
			.s_axi_awvalid	(s_axi_awvalid			), 
			.s_axi_awready	(s_axi_awready			),

			// AXI write data signals
			.s_axi_wdata	(s_axi_wdata			),
			.s_axi_wstrb	(s_axi_wstrb			),
			.s_axi_wlast	(s_axi_wlast			),
			.s_axi_wvalid	(s_axi_wvalid			),
			.s_axi_wready	(s_axi_wready			),

			// AXI write response signals
			.s_axi_bid		(s_axi_bid				),
			.s_axi_bresp	(s_axi_bresp			),
			.s_axi_bvalid	(s_axi_bvalid			),
			.s_axi_bready	(s_axi_bready			),

			// AXI read control signals
			.s_axi_arid		(s_axi_arid				),
			.s_axi_araddr	(s_axi_araddr			),
			.s_axi_arlen	(s_axi_arlen			),
			.s_axi_arsize	(s_axi_arsize			),
			.s_axi_arburst	(s_axi_arburst			),
			.s_axi_arvalid	(s_axi_arvalid			),
			.s_axi_arready	(s_axi_arready			),

			// AXI read data signals
			.s_axi_rid		(s_axi_rid				),
			.s_axi_rdata	(s_axi_rdata			),
			.s_axi_rresp	(s_axi_rresp			),
			.s_axi_rlast	(s_axi_rlast			),
			.s_axi_rvalid	(s_axi_rvalid			),
			.s_axi_rready	(s_axi_rready			)
		);
		assign s_aclk = clk;
		assign s_aresetn = rst_n;
		// AXI write control signals
		assign s_axi_awvalid = bram_wen;
		assign s_axi_awburst = 2'b0;
		assign s_axi_awsize = 3'b101;			// 32 bytes
		assign s_axi_awid = 4'd0;
		assign s_axi_awlen = 8'd0;
		assign s_axi_awaddr = {{(32 - `BLOCK_DEPTH_INDEX - BLOCK_NUM_INDEX){1'b0}}, {block_no, block_ptr}};
		assign s_axi_wlast = 1'b1;
		assign s_axi_wvalid = bram_wen;
		assign s_axi_wstrb = 32'hff_ff_ff_ff;	// all enable
		assign s_axi_wdata = bram_data_i;
		assign s_axi_bready = 1'b1;
		end
	endgenerate

endmodule
