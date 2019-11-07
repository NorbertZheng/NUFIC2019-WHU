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
					PRESET_SEQUENCE_LENG	=	64,
					PRESET_SEQUENCE			=	64'h00_01_02_03_04_05_06_07,
					DATA_BYTE_SHIFT			=	5
) (
	input								clk,
	input								rst_n,

	input		[WINDOW_WIDTH:0]		data_i,
	input								data_wen,

	output		[WINDOW_DEPTH - 1:0]	flag_o,

	// for debug_AXI_reader
	output	reg							AXI_reader_read_start,
	output	reg	[31:0]					AXI_reader_axi_araddr_start,
	input								AXI_reader_transmit_done,

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

	localparam		ThresholdCutterWindow_IDLE	=	3'b000,
					ThresholdCutterWindow_READ	=	3'b001,
					ThresholdCutterWindow_WRITE	=	3'b010,
					ThresholdCutterWindow_BREAK	=	3'b011,
					ThresholdCutterWindow_TAG	=	3'b100,
					ThresholdCutterWindow_END	=	3'b101,
					ThresholdCutterWindow_WAITRD=	3'b110;

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
	// reg [WINDOW_WIDTH - 1:0] window_data[WINDOW_DEPTH - 1:0];
	reg [WINDOW_DEPTH - 1:0] window_tag;
	reg [WINDOW_DEPTH_INDEX - 1:0] ptr;							// point to next loc to write
	// reg [WINDOW_DEPTH_INDEX - 1:0] ptrPlus1;					// next to write, restore it!!!
	reg [`BLOCK_DEPTH_INDEX - 1:0] block_ptr;
	// reg [BLOCK_NUM_INDEX - 1:0] block_no;
	wire break_flag = ~(|flag_o);								// all less than threshold
	reg window_data_fulfill;									// when first fulfill it, set to 1'b1, and never change
	reg [WINDOW_DEPTH_INDEX - 1:0] valid_cnt;					// when break_flag, set to 0, and set window_data_fulfill to 0
	reg data_wen_delay;
	// reg [127:0] preset_sequence = PRESET_SEQUENCE;
	wire [7:0] preset_sequence[PRESET_SEQUENCE_LENG - 1:0];
	genvar l;
	generate
	for (l = 0; l < (PRESET_SEQUENCE_LENG >> 3); l = l + 1)
		assign preset_sequence[l] = PRESET_SEQUENCE[(l << 3) + 7:(l << 3)];
	endgenerate
	reg write_tag;
	/*// for debug
	(* mark_debug = "true" *)wire [WINDOW_WIDTH - 1:0] debug_window_data[WINDOW_DEPTH - 1:0];
	genvar k;
	generate
	for (k = 0; k < WINDOW_DEPTH; k = k + 1)
		begin
		assign debug_window_data[k] = window_data[k];
		end
	endgenerate*/

	// window_data signals
	reg window_data_wen;
	reg [WINDOW_DEPTH_INDEX - 1:0] window_data_addr;
	reg [WINDOW_WIDTH - 1:0] window_data_data_i;
	wire [WINDOW_WIDTH - 1:0] window_data_data_o;

	// window_data
	wbram m_window_data(
		.clka		(clk				), 
		.ena		(1'b1				), 
		.wea		(window_data_wen	), 
		.addra		(window_data_addr	), 
		.dina		(window_data_data_i	), 
		.douta		(window_data_data_o	)
	);
	// assign window_data_addr = ptr - 1'b1;		// for 1-cycle delay

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

	reg [2:0] ThresholdCutterWindow_state;
	reg ThresholdCutterWindow_delay;
	reg [2:0] ThresholdCutterWindow_cnt;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// state
			ThresholdCutterWindow_state <= ThresholdCutterWindow_IDLE;
			// window_data
			window_data_addr <= {WINDOW_DEPTH_INDEX{1'b0}};
			window_data_data_i <= {WINDOW_WIDTH{1'b0}};
			window_data_wen <= 1'b0;
			// inner signals
			window_tag <= {WINDOW_DEPTH{1'b0}};
			ptr <= {WINDOW_DEPTH_INDEX{1'b0}};
			ThresholdCutterWindow_delay <= 1'b0;
			ThresholdCutterWindow_cnt <= 3'b0;
			block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};		// init as 0xffff, always point to the last write unit
			// block_no <= {BLOCK_NUM_INDEX{1'b0}};
			window_data_fulfill <= 1'b0;
			valid_cnt <= {WINDOW_DEPTH_INDEX{1'b0}};
			// for bram
			bram_wen <= 1'b0;
			bram_data_i <= {WINDOW_WIDTH{1'b0}};
			// output
			AXI_reader_read_start <= 1'b0;
			AXI_reader_axi_araddr_start <= 32'b0;
			end
		else
			begin
			data_wen_delay <= data_wen;
			if (!AXI_reader_transmit_done)
				begin
				// do nothing
				// state
				ThresholdCutterWindow_state <= ThresholdCutterWindow_IDLE;
				// window_data
				window_data_addr <= {WINDOW_DEPTH_INDEX{1'b0}};
				window_data_data_i <= {WINDOW_WIDTH{1'b0}};
				window_data_wen <= 1'b0;
				// inner signals
				window_tag <= {WINDOW_DEPTH{1'b0}};
				ptr <= {WINDOW_DEPTH_INDEX{1'b0}};
				ThresholdCutterWindow_delay <= 1'b0;
				ThresholdCutterWindow_cnt <= 3'b0;
				block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};		// init as 0xffff, always point to the last write unit
				// block_no <= {BLOCK_NUM_INDEX{1'b0}};
				window_data_fulfill <= 1'b0;
				valid_cnt <= {WINDOW_DEPTH_INDEX{1'b0}};
				// for bram
				bram_wen <= 1'b0;
				bram_data_i <= {WINDOW_WIDTH{1'b0}};
				// output
				AXI_reader_read_start <= 1'b0;
				AXI_reader_axi_araddr_start <= 32'b0;
				end
			else
			case (ThresholdCutterWindow_state)
				ThresholdCutterWindow_IDLE:
					begin
					if (data_wen)		// write data
						begin
						// window_data
						window_data_addr <= ptr;
						window_data_data_i <= data_i[WINDOW_WIDTH:1];
						window_data_wen <= 1'b1;
						// inner signals
						// window_data[ptr] <= data_i[WINDOW_WIDTH:1];
						window_tag[ptr] <= data_i[0];
						if (ptr == WINDOW_DEPTH - 1)		ptr <= {WINDOW_DEPTH_INDEX{1'b0}};			// back up
						else								ptr <= ptr + 1'b1;
						if (valid_cnt == WINDOW_DEPTH - 1)					// we fulfill the window_data
							begin
							window_data_fulfill <= 1'b1;
							end
						else if (data_i[0])		// valid!
							begin
							valid_cnt <= valid_cnt + 1'b1;
							end
						else
							begin
							valid_cnt <= {WINDOW_DEPTH_INDEX{1'b0}};
							end
						// output
						AXI_reader_read_start <= 1'b0;
						AXI_reader_axi_araddr_start <= 32'b0;
						end
					else if (break_flag)
						begin
						// window_data
						window_data_data_i <= {WINDOW_WIDTH{1'b0}};
						window_data_wen <= 1'b0;
						if (block_ptr == {`BLOCK_DEPTH_INDEX{1'b1}})
							begin
							// do nothing
							// inner signals
							block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};
							valid_cnt <= {WINDOW_DEPTH{1'b0}};
							window_data_fulfill <= 1'b0;
							// for bram
							bram_wen <= 1'b0;						// not write bram
							bram_data_i <= {WINDOW_WIDTH{1'b0}};
							// output
							AXI_reader_read_start <= 1'b0;
							AXI_reader_axi_araddr_start <= 32'b0;
							end
						else
							begin
							// state
							ThresholdCutterWindow_state <= ThresholdCutterWindow_BREAK;
							// inner signals
							ThresholdCutterWindow_cnt <= 3'b0;
							end
						end
					else if (window_data_fulfill)		// data is valid
						begin
						// window_data
						window_data_data_i <= {WINDOW_WIDTH{1'b0}};
						window_data_wen <= 1'b0;
						if (data_wen_delay)						// ensure 1-period write, avoid double-write
							begin
							if ((block_ptr < `BLOCK_DEPTH) || (block_ptr == {`BLOCK_DEPTH_INDEX{1'b1}}))		// current block is not full, even empty
								begin
								// state
								ThresholdCutterWindow_state <= ThresholdCutterWindow_READ;
								// inner signals, window_data & ptr do not change
								ThresholdCutterWindow_delay <= 1'b0;
								block_ptr <= block_ptr + 1'b1;
								// window_data
								window_data_addr <= ptr;
								// for bram
								bram_wen <= 1'b0;
								// output
								AXI_reader_read_start <= 1'b0;
								AXI_reader_axi_araddr_start <= 32'b0;
								if (block_ptr == `BLOCK_DEPTH - 1)
									begin
									// state
									ThresholdCutterWindow_state <= ThresholdCutterWindow_TAG;
									end
								end
							end
						else
							begin
							// for bram
							bram_wen <= 1'b0;
							// output
							AXI_reader_read_start <= 1'b0;
							AXI_reader_axi_araddr_start <= 32'b0;
							end
						end
					else										// data is trying to be valid, do nothing(wait the last to be valid)
						begin
						// do nothing
						// output
						AXI_reader_read_start <= 1'b0;
						AXI_reader_axi_araddr_start <= 32'b0;
						end
					end
				ThresholdCutterWindow_READ:
					begin
					// window_data
					window_data_data_i <= {WINDOW_WIDTH{1'b0}};
					window_data_wen <= 1'b0;
					// block_no <= {BLOCK_NUM_INDEX{1'b0}};
					// for bram
					bram_wen <= 1'b0;
					bram_data_i <= {WINDOW_WIDTH{1'b0}};
					// output
					AXI_reader_read_start <= 1'b0;
					AXI_reader_axi_araddr_start <= 32'b0;
					if (!ThresholdCutterWindow_delay)
						begin
						// do nothing
						ThresholdCutterWindow_delay <= ThresholdCutterWindow_delay + 1'b1;
						end
					else
						begin
						// state
						ThresholdCutterWindow_state <= ThresholdCutterWindow_WRITE;
						end
					end
				ThresholdCutterWindow_WRITE:
					begin
					// window_data
					window_data_data_i <= {WINDOW_WIDTH{1'b0}};
					window_data_wen <= 1'b0;
					// output
					AXI_reader_read_start <= 1'b0;
					AXI_reader_axi_araddr_start <= 32'b0;
					if (ThresholdCutterWindow_cnt == 3'b000)
						begin
						// for bram
						bram_wen <= 1'b1;
						bram_data_i <= window_data_data_o;
						ThresholdCutterWindow_cnt <= ThresholdCutterWindow_cnt + 1'b1;
						end
					else
						begin
						if (ThresholdCutterWindow_cnt == 3'b010)
							begin
							ThresholdCutterWindow_cnt <= ThresholdCutterWindow_cnt + 1'b1;
							// for bram
							bram_wen <= 1'b0;
							end
						else if (ThresholdCutterWindow_cnt == 3'b011)
							begin
							// for bram
							bram_wen <= 1'b0;
							// inner signals
							ThresholdCutterWindow_cnt <= 3'b0;
							// state
							ThresholdCutterWindow_state <= ThresholdCutterWindow_IDLE;
							end
						else
							begin
							// for bram
							bram_wen <= 1'b0;
							ThresholdCutterWindow_cnt <= ThresholdCutterWindow_cnt + 1'b1;
							end
						end
					end
				ThresholdCutterWindow_BREAK:
					begin
					// window_data
					window_data_data_i <= {WINDOW_WIDTH{1'b0}};
					window_data_wen <= 1'b0;
					if (block_ptr < WINDOW_DEPTH)
						begin
						// state
						ThresholdCutterWindow_state <= ThresholdCutterWindow_IDLE;
						// inner signals
						valid_cnt <= {WINDOW_DEPTH{1'b0}};
						window_data_fulfill <= 1'b0;
						block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};
						// output
						AXI_reader_read_start <= 1'b0;
						AXI_reader_axi_araddr_start <= 32'b0;
						// for bram
						bram_wen <= 1'b0;
						bram_data_i <= {WINDOW_WIDTH{1'b0}};
						end
					else if (block_ptr < `BLOCK_DEPTH)			// current block is not full, fill it with 32'b0
						begin
						// inner signals
						valid_cnt <= {WINDOW_DEPTH{1'b0}};
						window_data_fulfill <= 1'b0;
						// output
						AXI_reader_read_start <= 1'b0;
						AXI_reader_axi_araddr_start <= 32'b0;
						if (ThresholdCutterWindow_cnt == 3'b000)
							begin
							ThresholdCutterWindow_cnt <= ThresholdCutterWindow_cnt + 1'b1;
							// inner signals, window_data & ptr do not change
							block_ptr <= block_ptr + 1'b1;
							ThresholdCutterWindow_delay <= 1'b1;
							// for bram
							bram_wen <= 1'b1;
							bram_data_i <= {WINDOW_WIDTH{1'b0}};
							if (block_ptr == `BLOCK_DEPTH - 1)
								begin
								// state
								ThresholdCutterWindow_state <= ThresholdCutterWindow_TAG;
								end
							end
						else
							begin
							// inner signals
							if (ThresholdCutterWindow_cnt == 3'b010)
								begin
								ThresholdCutterWindow_cnt <= ThresholdCutterWindow_cnt + 1'b1;
								// for bram
								bram_wen <= 1'b0;
								end
							else if (ThresholdCutterWindow_cnt == 3'b011)
								begin
								ThresholdCutterWindow_cnt <= 3'b0;
								// for bram
								bram_wen <= 1'b0;
								end
							else
								begin
								ThresholdCutterWindow_cnt <= ThresholdCutterWindow_cnt + 1'b1;
								end
							end
						end
					end
				ThresholdCutterWindow_TAG:
					begin
					// state
					ThresholdCutterWindow_state <= ThresholdCutterWindow_END;
					// window_data
					window_data_data_i <= {WINDOW_WIDTH{1'b0}};
					window_data_wen <= 1'b0;
					// inner signals, window_data & ptr do not change
					block_ptr <= block_ptr + 1'b1;
					// for bram
					bram_wen <= 1'b1;
					bram_data_i <= {WINDOW_WIDTH{1'b1}};
					end
				ThresholdCutterWindow_END:
					begin
					// state
					ThresholdCutterWindow_state <= ThresholdCutterWindow_IDLE;
					// window_data
					window_data_data_i <= {WINDOW_WIDTH{1'b0}};
					window_data_wen <= 1'b0;
					// inner signals, window_data & ptr do not change
					block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};
					// for bram
					bram_wen <= 1'b0;
					bram_data_i <= {WINDOW_WIDTH{1'b0}};
					// output
					AXI_reader_read_start <= 1'b1;
					AXI_reader_axi_araddr_start <= 32'b0;
					end
				default:
					begin
					// state
					ThresholdCutterWindow_state <= ThresholdCutterWindow_IDLE;
					// window_data
					window_data_addr <= {WINDOW_DEPTH_INDEX{1'b0}};
					window_data_data_i <= {WINDOW_WIDTH{1'b0}};
					window_data_wen <= 1'b0;
					// inner signals
					ThresholdCutterWindow_delay <= 1'b0;
					window_tag <= {WINDOW_DEPTH{1'b0}};
					ptr <= {WINDOW_DEPTH_INDEX{1'b0}};
					block_ptr <= {`BLOCK_DEPTH_INDEX{1'b1}};		// init as 0xffff, always point to the last write unit
					// block_no <= {BLOCK_NUM_INDEX{1'b0}};
					window_data_fulfill <= 1'b0;
					valid_cnt <= {WINDOW_DEPTH_INDEX{1'b0}};
					// for bram
					bram_wen <= 1'b0;
					bram_data_i <= {WINDOW_WIDTH{1'b0}};
					// output
					AXI_reader_read_start <= 1'b0;
					AXI_reader_axi_araddr_start <= 32'b0;
					end
			endcase
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
		assign s_axi_awaddr = {{(32 - `BLOCK_DEPTH_INDEX - BLOCK_NUM_INDEX - DATA_BYTE_SHIFT){1'b0}}, block_ptr, {DATA_BYTE_SHIFT{1'b0}}};
		// assign s_axi_awaddr = {{(32 - `BLOCK_DEPTH_INDEX - BLOCK_NUM_INDEX - DATA_BYTE_SHIFT){1'b0}}, {block_no, block_ptr}, {DATA_BYTE_SHIFT{1'b0}}};
		assign s_axi_wlast = 1'b1;
		assign s_axi_wvalid = bram_wen;
		assign s_axi_wstrb = 32'hff_ff_ff_ff;	// all enable
		assign s_axi_wdata = bram_data_i;
		assign s_axi_bready = 1'b1;
		end
	endgenerate

endmodule
