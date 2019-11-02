module ThresholdCutter #(
	parameter		// config enable
					CONFIG_EN							=	0,		// do not enable config
					// config
					CLK_FRE								=	50,		// 50MHz
					BAUD_RATE							=	115200,	// 115200Hz (4800, 19200, 38400, 57600, 115200, 38400...)
					STOP_BIT							=	0,		// 0 : 1-bit stop-bit, 1 : 2-bit stop-bit
					CHECK_BIT							=	0,		// 0 : no check-bit, 1 : odd, 2 : even
					// default	9600	0	0
					// granularity
					REQUEST_FIFO_DATA_WIDTH				=	8,		// the bit width of data we stored in the FIFO
					REQUEST_FIFO_DATA_DEPTH_INDEX		=	6,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					RESPONSE_FIFO_DATA_WIDTH			=	8,		// the bit width of data we stored in the FIFO
					RESPONSE_FIFO_DATA_DEPTH_INDEX		=	6,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					// uart connected with PC
					PC_BAUD_RATE						=	115200,	// 115200Hz
					// enable simulation
					SIM_ENABLE							=	0,				// enable simulation
					// parameter for window
					WINDOW_DEPTH_INDEX					=	7,				// support up to 128 windows
					WINDOW_DEPTH						=	100,			// 100 windows
					WINDOW_WIDTH						=	(32 << 3),		// 32B window
	`define			WINDOW_SUB_WIDTH					(8 << 3)
					THRESHOLD							=	32'h0010_0000,	// threshold
					G_THRESHOLD							=	32'h0040_0000,
					BLOCK_NUM_INDEX						=	4,				// 2 ** 6 == 64 blocks		// 16
					// parameter for package
					A_OFFSET							=	2,				// A's offset
					// parameter for square
					SQUARE_SRC_DATA_WIDTH				=	16,				// square src data width
	`ifndef			SQUARE_RES_DATA_WIDTH
	`define			SQUARE_RES_DATA_WIDTH				(SQUARE_SRC_DATA_WIDTH << 1)
	`endif
					// parameter for preset-sequence
					PRESET_SEQUENCE_LENG				=	64,
					PRESET_SEQUENCE						=	64'h00_01_02_03_04_05_06_07,
					// parameter for package
					PACKAGE_SIZE						=	11,
					PACKAGE_NUM							=	4,
					DATA_BYTE_SHIFT						=	5
	`define			PACKAGE_TOLSIZE						(PACKAGE_NUM * PACKAGE_SIZE)
	`define			PACKAGE_START						1
	`define			PACKAGE_FUNC						2
	`define			PACKAGE_SUM							11
	`define			PACKAGE_NO_INDEX					6					// 2 ** 6 == 64
) (
	input									clk					,
	input									rst_n				,

	// BlueTooth_Config
	input									BlueTooth_State		,
	output									BlueTooth_Key		,
	output									BlueTooth_Rxd		,
	input									BlueTooth_Txd		,
	output									BlueTooth_Vcc		,
	output									BlueTooth_Gnd		,

	// ThresholdCutterWindow signals
	output		[WINDOW_DEPTH - 1:0]		ThresholdCutterWindow_flag_o	,

	output									AXI_reader_read_start			,
	output		[31:0]						AXI_reader_axi_araddr_start		,
	input									AXI_reader_transmit_done		,

	// AXI RAM signals
	// ram safe access
	output									rsta_busy			,
	output									rstb_busy			,

	// AXI read control signals
	input		[3:0]						s_axi_arid			,
	input		[31:0]						s_axi_araddr		,
	input		[7:0]						s_axi_arlen			,
	input		[2:0]						s_axi_arsize		,
	input		[1:0]						s_axi_arburst		,
	input									s_axi_arvalid		,
	output									s_axi_arready		,

	// AXI read data signals
	output		[3:0]						s_axi_rid			,
	output		[255:0]						s_axi_rdata			,
	output		[1:0]						s_axi_rresp			,
	output									s_axi_rlast			,
	output									s_axi_rvalid		,
	input									s_axi_rready		
);

	localparam			WIN_IDLE		=	2'b00,
						WIN_PREPARE		=	2'b01,
						WIN_WRDATA		=	2'b10;

	// PLL signals
	wire clk_50m, sys_rst_n;

	// ThresholdCutterWindow signals
	reg [WINDOW_WIDTH:0] ThresholdCutterWindow_data_i;
	reg ThresholdCutterWindow_data_wen;
	(* mark_debug = "true" *)wire debug_ThresholdCutterWindow_data_wen = ThresholdCutterWindow_data_wen;
	(* mark_debug = "true" *)wire [WINDOW_DEPTH - 1:0] debug_ThresholdCutterWindow_flag_o = ThresholdCutterWindow_flag_o;

	// BlueToothController signals
	// reg BlueTooth_request_FIFO_data_i_vld, BlueTooth_response_FIFO_r_en;
	reg BlueTooth_response_FIFO_r_en;
	wire BlueTooth_request_FIFO_data_i_vld = 1'b0;
	wire BlueTooth_request_FIFO_data_i_rdy, BlueTooth_request_FIFO_full, BlueTooth_request_FIFO_empty;
	wire BlueTooth_response_FIFO_data_o_vld, BlueTooth_response_FIFO_full, BlueTooth_response_FIFO_empty;
	wire [REQUEST_FIFO_DATA_DEPTH_INDEX - 1:0] BlueTooth_request_FIFO_surplus;
	wire [RESPONSE_FIFO_DATA_DEPTH_INDEX - 1:0] BlueTooth_response_FIFO_surplus;
	// reg [REQUEST_FIFO_DATA_WIDTH - 1:0] BlueTooth_request_FIFO_data_i;
	wire [REQUEST_FIFO_DATA_WIDTH - 1:0] BlueTooth_request_FIFO_data_i = {REQUEST_FIFO_DATA_WIDTH{1'b0}};;
	wire [RESPONSE_FIFO_DATA_WIDTH - 1:0] BlueTooth_response_FIFO_data_o;
	(* mark_debug = "true" *)wire [RESPONSE_FIFO_DATA_WIDTH - 1:0] debug_BlueTooth_response_FIFO_data_o = BlueTooth_response_FIFO_data_o;
	(* mark_debug = "true" *)wire [WINDOW_WIDTH:0] debug_ThresholdCutterWindow_data_i = ThresholdCutterWindow_data_i;
	// for debug
	reg BlueTooth_State_reg;
	always@ (posedge clk_50m)
		BlueTooth_State_reg <= BlueTooth_State;
	(* mark_debug = "true" *)wire debug_BlueTooth_State = BlueTooth_State_reg;

	// read one complete package to window
	reg [1:0] ThresholdCutter_win_state;
	reg [`PACKAGE_NO_INDEX - 1:0] ThresholdCutter_win_cnt;
	reg [SQUARE_SRC_DATA_WIDTH - 1:0] Ax, Ay, Az;
	(* mark_debug = "true" *)wire [SQUARE_SRC_DATA_WIDTH - 1:0] debug_Ax = Ax;
	(* mark_debug = "true" *)wire [SQUARE_SRC_DATA_WIDTH - 1:0] debug_Ay = Ay;
	(* mark_debug = "true" *)wire [SQUARE_SRC_DATA_WIDTH - 1:0] debug_Az = Az;
	wire squareSumCo, tempSquareSumCo, package_energy;
	wire [`SQUARE_RES_DATA_WIDTH - 1:0] AxSquare, AySquare, AzSquare, tempSquareSum, squareSum;
	/*// AxSquare
	square #(
		.SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH)
	) m_AxSquare (
		// temp useless
		.clk		(clk													),
		.rst_n		(rst_n													),

		// square src
		.src0		(Ax														),
		.src1		(Ax														),

		// square res
		.res		(AxSquare												)
	);*/
	assign AxSquare = Ax * Ax;
	/*// AySquare
	square #(
		.SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH)
	) m_AySquare (
		// temp useless
		.clk		(clk													),
		.rst_n		(rst_n													),

		// square src
		.src0		(Ay														),
		.src1		(Ay														),

		// square res
		.res		(AySquare												)
	);*/
	assign AySquare = Ay * Ay;
	/*// AzSquare
	square #(
		.SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH)
	) m_AzSquare (
		// temp useless
		.clk		(clk													),
		.rst_n		(rst_n													),

		// square src
		.src0		(Az														),
		.src1		(Az														),

		// square res
		.res		(AzSquare												)
	);*/
	assign AzSquare = Az * Az;
	// tempSquareSum
	cla32 m_tempSquareSum(
		.a			(AxSquare												),
		.b			(AySquare												),
		.ci			(1'b0													),
		.s			(tempSquareSum											),
		.co			(tempSquareSumCo										)
	);
	// squareSum
	cla32 m_squareSum(
		.a			(tempSquareSum											),
		.b			(AzSquare												),
		.ci			(1'b0													),
		.s			(squareSum												),
		.co			(squareSumCo											)
	);
	// package_energy
	assign package_energy = (squareSumCo | tempSquareSumCo | (squareSum >= G_THRESHOLD + THRESHOLD) || (squareSum <= G_THRESHOLD - THRESHOLD));
	(* mark_debug = "true" *)wire [`SQUARE_RES_DATA_WIDTH - 1:0] debug_AxSquare = AxSquare;
	(* mark_debug = "true" *)wire [`SQUARE_RES_DATA_WIDTH - 1:0] debug_AySquare = AySquare;
	(* mark_debug = "true" *)wire [`SQUARE_RES_DATA_WIDTH - 1:0] debug_AzSquare = AzSquare;
	(* mark_debug = "true" *)wire [`SQUARE_RES_DATA_WIDTH - 1:0] debug_tempSquareSum = tempSquareSum;
	(* mark_debug = "true" *)wire [`SQUARE_RES_DATA_WIDTH - 1:0] debug_squareSum = squareSum;
	(* mark_debug = "true" *)wire debug_tempSquareSumCo = tempSquareSumCo;
	(* mark_debug = "true" *)wire debug_squareSumCo = squareSumCo;
	always@ (posedge clk_50m)
		begin
		if (!sys_rst_n)
			begin
			// state
			ThresholdCutter_win_state <= WIN_IDLE;
			// inner signals
			ThresholdCutter_win_cnt <= {`PACKAGE_NO_INDEX{1'b0}};
			Ax <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
			Ay <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
			Az <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
			// response FIFO signals
			BlueTooth_response_FIFO_r_en <= 1'b0;
			// ThresholdCutterWindow signals
			ThresholdCutterWindow_data_i <= {(WINDOW_WIDTH + 1){1'b0}};
			ThresholdCutterWindow_data_wen <= 1'b0;
			end
		else
			begin
			case (ThresholdCutter_win_state)
				WIN_IDLE:
					begin
					if (!BlueTooth_response_FIFO_empty && (BlueTooth_response_FIFO_surplus <= {RESPONSE_FIFO_DATA_DEPTH_INDEX{1'b1}} - `PACKAGE_TOLSIZE))			// response FIFO is not empty
						begin
						// state
						ThresholdCutter_win_state <= WIN_PREPARE;
						// inner signals
						ThresholdCutter_win_cnt <= {`PACKAGE_NO_INDEX{1'b0}};
						/*Ax <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
						Ay <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
						Az <= {SQUARE_SRC_DATA_WIDTH{1'b0}};*/
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b1;
						// ThresholdCutterWindow signals
						ThresholdCutterWindow_data_i <= {(WINDOW_WIDTH + 1){1'b0}};
						ThresholdCutterWindow_data_wen <= 1'b0;
						end
					else
						begin
						// state
						ThresholdCutter_win_state <= WIN_IDLE;
						// inner signals
						ThresholdCutter_win_cnt <= {`PACKAGE_NO_INDEX{1'b0}};
						/*Ax <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
						Ay <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
						Az <= {SQUARE_SRC_DATA_WIDTH{1'b0}};*/
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b0;
						// ThresholdCutterWindow signals
						ThresholdCutterWindow_data_i <= {(WINDOW_WIDTH + 1){1'b0}};
						ThresholdCutterWindow_data_wen <= 1'b0;
						end
					end
				WIN_PREPARE:											// at the same posedge clk, FIFO is reading data
					begin
					// inner signals
					ThresholdCutter_win_cnt <= ThresholdCutter_win_cnt + 1'b1;
					if ((ThresholdCutter_win_cnt < `PACKAGE_TOLSIZE - 1) && (ThresholdCutter_win_cnt > 0))		// loss 2
						begin
						if ((ThresholdCutter_win_cnt == (0 * PACKAGE_SIZE + `PACKAGE_START)) ||
							(ThresholdCutter_win_cnt == (0 * PACKAGE_SIZE + `PACKAGE_FUNC)) ||
							(ThresholdCutter_win_cnt == (0 * PACKAGE_SIZE + `PACKAGE_SUM)) ||
							(ThresholdCutter_win_cnt == (1 * PACKAGE_SIZE + `PACKAGE_START)) ||
							(ThresholdCutter_win_cnt == (1 * PACKAGE_SIZE + `PACKAGE_FUNC)) ||
							(ThresholdCutter_win_cnt == (1 * PACKAGE_SIZE + `PACKAGE_SUM)) ||
							(ThresholdCutter_win_cnt == (2 * PACKAGE_SIZE + `PACKAGE_START)) ||
							(ThresholdCutter_win_cnt == (2 * PACKAGE_SIZE + `PACKAGE_FUNC)) ||
							(ThresholdCutter_win_cnt == (2 * PACKAGE_SIZE + `PACKAGE_SUM)) ||
							(ThresholdCutter_win_cnt == (3 * PACKAGE_SIZE + `PACKAGE_START)) ||
							(ThresholdCutter_win_cnt == (3 * PACKAGE_SIZE + `PACKAGE_FUNC)) ||
							(ThresholdCutter_win_cnt == (3 * PACKAGE_SIZE + `PACKAGE_SUM)))
							begin
							// do nothhing
							ThresholdCutterWindow_data_wen <= 1'b0;
							end
						else
							begin
							// ThresholdCutterWindow signals
							ThresholdCutterWindow_data_i <= {ThresholdCutterWindow_data_i[WINDOW_WIDTH - 8:1], BlueTooth_response_FIFO_data_o, package_energy};
							ThresholdCutterWindow_data_wen <= 1'b0;
							end
						end
					else if (ThresholdCutter_win_cnt ==`PACKAGE_TOLSIZE - 1)
						begin
						// inner
						Ax <=	ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 16] ? 
								(~({ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 16:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 23], 
								ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 8:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 15]}) + 1) :
								({ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 16:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 23], 
								ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 8:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 15]});
						Ay <=	ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 32] ? 
								(~({ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 32:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 39], 
								ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 24:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 31]}) + 1) : 
								({ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 32:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 39], 
								ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 24:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 31]});
						Az <=	ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 48] ? 
								(~({ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 48:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 55], 
								ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 40:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 47]}) + 1) : 
								({ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 48:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 55], 
								ThresholdCutterWindow_data_i[WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 40:WINDOW_WIDTH - `WINDOW_SUB_WIDTH - 47]});
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b0;
						// ThresholdCutterWindow signals
						// it's PACKAGE_SUM
						// ThresholdCutterWindow_data_i <= {ThresholdCutterWindow_data_i[WINDOW_WIDTH - 8:1], BlueTooth_response_FIFO_data_o, package_energy};
						ThresholdCutterWindow_data_wen <= 1'b0;
						end
					else if (ThresholdCutter_win_cnt ==`PACKAGE_TOLSIZE)
						begin
						// state
						ThresholdCutter_win_state <= WIN_WRDATA;
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b0;
						// ThresholdCutterWindow signals
						ThresholdCutterWindow_data_i <= {ThresholdCutterWindow_data_i[WINDOW_WIDTH - 8:1], BlueTooth_response_FIFO_data_o, package_energy};
						ThresholdCutterWindow_data_wen <= 1'b1;
						end
					end
				WIN_WRDATA:
					begin
					// state
					ThresholdCutter_win_state <= WIN_IDLE;
					// inner signals
					ThresholdCutter_win_cnt <= {`PACKAGE_NO_INDEX{1'b0}};
					/*Ax <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
					Ay <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
					Az <= {SQUARE_SRC_DATA_WIDTH{1'b0}};*/
					// response FIFO signals
					BlueTooth_response_FIFO_r_en <= 1'b0;
					// ThresholdCutterWindow signals
					ThresholdCutterWindow_data_i <= {(WINDOW_WIDTH + 1){1'b0}};
					ThresholdCutterWindow_data_wen <= 1'b0;
					end
				default:
					begin
					// state
					ThresholdCutter_win_state <= WIN_IDLE;
					// inner signals
					ThresholdCutter_win_cnt <= {`PACKAGE_NO_INDEX{1'b0}};
					Ax <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
					Ay <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
					Az <= {SQUARE_SRC_DATA_WIDTH{1'b0}};
					// response FIFO signals
					BlueTooth_response_FIFO_r_en <= 1'b0;
					// ThresholdCutterWindow signals
					ThresholdCutterWindow_data_i <= {(WINDOW_WIDTH + 1){1'b0}};
					ThresholdCutterWindow_data_wen <= 1'b0;
					end
			endcase
			end
		end

	generate
	if (SIM_ENABLE)
		begin
		assign clk_50m = clk;
		assign sys_rst_n = rst_n;
		end
	else
		begin
		/*// PLL
		pll m_pll (
			.clk_50m		(clk_50m		),
			.reset			(rst_n			),
			.locked			(sys_rst_n		),
			.clk_in1		(clk			)
		);*/
		assign clk_50m = clk;
		assign sys_rst_n = rst_n;
		end
	endgenerate

	// BlueToothController
	BlueToothController #(
		.CONFIG_EN(CONFIG_EN),												// do not enable config
		.CLK_FRE(CLK_FRE),													// 50MHz
		.BAUD_RATE(BAUD_RATE),												// 9600Hz (4800, 19200, 38400, 57600, 115200...)
		.STOP_BIT(STOP_BIT),												// 0 : 1-bit stop-bit, 1 : 2-bit stop-bit
		.CHECK_BIT(CHECK_BIT),												// 0 : no check-bit, 1 : odd, 2 : even
		.REQUEST_FIFO_DATA_WIDTH(REQUEST_FIFO_DATA_WIDTH),					// the bit width of data we stored in the FIFO
		.REQUEST_FIFO_DATA_DEPTH_INDEX(REQUEST_FIFO_DATA_DEPTH_INDEX),		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
		.RESPONSE_FIFO_DATA_WIDTH(RESPONSE_FIFO_DATA_WIDTH),				// the bit width of data we stored in the FIFO
		.RESPONSE_FIFO_DATA_DEPTH_INDEX(RESPONSE_FIFO_DATA_DEPTH_INDEX)		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
	) m_BlueToothController (
		.clk											(clk_50m								),
		.rst_n											(sys_rst_n								),

		// BlueTooth_Config
		.BlueTooth_State								(BlueTooth_State					),
		.BlueTooth_Key									(BlueTooth_Key						),
		.BlueTooth_Rxd									(BlueTooth_Rxd						),
		.BlueTooth_Txd									(BlueTooth_Txd						),
		.BlueTooth_Vcc									(BlueTooth_Vcc						),
		.BlueTooth_Gnd									(BlueTooth_Gnd						),

		// request FIFO signals
		.cmd_handler_BlueTooth_request_FIFO_data_i		(BlueTooth_request_FIFO_data_i		),
		.cmd_handler_BlueTooth_request_FIFO_data_i_vld	(BlueTooth_request_FIFO_data_i_vld	),
		.cmd_handler_BlueTooth_request_FIFO_data_i_rdy	(BlueTooth_request_FIFO_data_i_rdy	),
		// for debug
		.cmd_handler_BlueTooth_request_FIFO_full		(BlueTooth_request_FIFO_full		),
		.cmd_handler_BlueTooth_request_FIFO_empty		(BlueTooth_request_FIFO_empty		),
		.cmd_handler_BlueTooth_request_FIFO_surplus		(BlueTooth_request_FIFO_surplus		),

		// response FIFO signals
		.cmd_handler_BlueTooth_response_FIFO_r_en		(BlueTooth_response_FIFO_r_en		),
		.cmd_handler_BlueTooth_response_FIFO_data_o		(BlueTooth_response_FIFO_data_o		),
		.cmd_handler_BlueTooth_response_FIFO_data_o_vld	(BlueTooth_response_FIFO_data_o_vld	),
		// for debug
		.cmd_handler_BlueTooth_response_FIFO_full		(BlueTooth_response_FIFO_full		),
		.cmd_handler_BlueTooth_response_FIFO_empty		(BlueTooth_response_FIFO_empty		),
		.cmd_handler_BlueTooth_response_FIFO_surplus	(BlueTooth_response_FIFO_surplus	)
	);

	// ThresholdCutterWindow
	ThresholdCutterWindow #(
		// enable simulation
		.SIM_ENABLE(SIM_ENABLE),				// enable simulation
		// parameter for window
		.WINDOW_DEPTH_INDEX(WINDOW_DEPTH_INDEX),				// support up to 128 windows
		.WINDOW_DEPTH(WINDOW_DEPTH),			// 100 windows
		.WINDOW_WIDTH(WINDOW_WIDTH),		// 32B window
		.THRESHOLD(THRESHOLD),	// threshold
		.BLOCK_NUM_INDEX(BLOCK_NUM_INDEX),				// 2 ** 6 == 64 blocks		// 16
		// parameter for package
		.A_OFFSET(A_OFFSET),				// A's offset
		// parameter for square
		.SQUARE_SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH),				// square src data width
		// parameter for preset-sequence
		.PRESET_SEQUENCE_LENG(PRESET_SEQUENCE_LENG),
		.PRESET_SEQUENCE(PRESET_SEQUENCE),
		.DATA_BYTE_SHIFT(DATA_BYTE_SHIFT)
	) m_ThresholdCutterWindow (
		.clk							(clk_50m								),
		.rst_n							(rst_n									),

		.data_i							(ThresholdCutterWindow_data_i			),
		.data_wen						(ThresholdCutterWindow_data_wen			),

		.flag_o							(ThresholdCutterWindow_flag_o			),

		.AXI_reader_read_start			(AXI_reader_read_start					),
		.AXI_reader_axi_araddr_start	(AXI_reader_axi_araddr_start			),
		.AXI_reader_transmit_done		(AXI_reader_transmit_done				),

		// AXI RAM signals
		// ram safe access
		.rsta_busy						(rsta_busy								),
		.rstb_busy						(rstb_busy								),

		// AXI read control signals
		.s_axi_arid						(s_axi_arid								),
		.s_axi_araddr					(s_axi_araddr							),
		.s_axi_arlen					(s_axi_arlen							),
		.s_axi_arsize					(s_axi_arsize							),
		.s_axi_arburst					(s_axi_arburst							),
		.s_axi_arvalid					(s_axi_arvalid							),
		.s_axi_arready					(s_axi_arready							),

		// AXI read data signals
		.s_axi_rid						(s_axi_rid								),
		.s_axi_rdata					(s_axi_rdata							),
		.s_axi_rresp					(s_axi_rresp							),
		.s_axi_rlast					(s_axi_rlast							),
		.s_axi_rvalid					(s_axi_rvalid							),
		.s_axi_rready					(s_axi_rready							)
	);

endmodule
