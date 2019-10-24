module debug_ThresholdCutter #(
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
					REQUEST_FIFO_DATA_DEPTH_INDEX		=	5,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					RESPONSE_FIFO_DATA_WIDTH			=	8,		// the bit width of data we stored in the FIFO
					RESPONSE_FIFO_DATA_DEPTH_INDEX		=	5,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					// uart connected with PC
					PC_BAUD_RATE						=	115200,	// 115200Hz
					// enable simulation
					SIM_ENABLE							=	0,				// enable simulation
					// parameter for window
					WINDOW_DEPTH_INDEX					=	7,				// support up to 128 windows
					WINDOW_DEPTH						=	100,			// 100 windows
					WINDOW_WIDTH						=	(32 << 3),		// 32B window
					THRESHOLD							=	32'h0010_0000,	// threshold
					BLOCK_NUM_INDEX						=	4,				// 2 ** 6 == 64 blocks		// 16
					// parameter for package
					A_OFFSET							=	2,				// A's offset
					// parameter for square
					SQUARE_SRC_DATA_WIDTH				=	16,				// square src data width
					// parameter for preset-sequence
					PRESET_SEQUENCE						=	128'h00_01_02_03_04_05_06_07_08_09_00_01_02_03_04_05,
					// parameter for package
					PACKAGE_SIZE						=	11,
					PACKAGE_NUM							=	4
) (
	input									clk					,
	input									rst_n				,

	// BlueTooth_Config
	input									BlueTooth_State		,
	output									BlueTooth_Key		,
	output									BlueTooth_Rxd		,
	input									BlueTooth_Txd		,
	output									BlueTooth_Vcc		,
	output									BlueTooth_Gnd		

	/*// ThresholdCutterWindow signals
	output		[WINDOW_DEPTH - 1:0]		ThresholdCutterWindow_flag_o	,

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
	input									s_axi_rready		*/
);

	// ThresholdCutter
	ThresholdCutter #(
		// config enable
		.CONFIG_EN(CONFIG_EN),		// do not enable config
		// config
		.CLK_FRE(CLK_FRE),		// 50MHz
		.BAUD_RATE(BAUD_RATE),	// 115200Hz (4800, 19200, 38400, 57600, 115200, 38400...)
		.STOP_BIT(STOP_BIT),		// 0 : 1-bit stop-bit, 1 : 2-bit stop-bit
		.CHECK_BIT(CHECK_BIT),		// 0 : no check-bit, 1 : odd, 2 : even
		// default	9600	0	0
		// granularity
		.REQUEST_FIFO_DATA_WIDTH(REQUEST_FIFO_DATA_WIDTH),		// the bit width of data we stored in the FIFO
		.REQUEST_FIFO_DATA_DEPTH_INDEX(REQUEST_FIFO_DATA_DEPTH_INDEX),		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
		.RESPONSE_FIFO_DATA_WIDTH(RESPONSE_FIFO_DATA_WIDTH),		// the bit width of data we stored in the FIFO
		.RESPONSE_FIFO_DATA_DEPTH_INDEX(RESPONSE_FIFO_DATA_DEPTH_INDEX),		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
		// uart connected with PC
		.PC_BAUD_RATE(PC_BAUD_RATE),	// 115200Hz
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
		.PRESET_SEQUENCE(PRESET_SEQUENCE),
		// parameter for package
		.PACKAGE_SIZE(PACKAGE_SIZE),
		.PACKAGE_NUM(PACKAGE_NUM)
	) (
		.clk							(clk				),
		.rst_n							(rst_n				),

		// BlueTooth_Config
		.BlueTooth_State				(BlueTooth_State	),
		.BlueTooth_Key					(BlueTooth_Key		),
		.BlueTooth_Rxd					(BlueTooth_Rxd		),
		.BlueTooth_Txd					(BlueTooth_Txd		),
		.BlueTooth_Vcc					(BlueTooth_Vcc		),
		.BlueTooth_Gnd					(BlueTooth_Gnd		),

		// ThresholdCutterWindow signals
		.ThresholdCutterWindow_flag_o	(					),

		// AXI RAM signals
		// ram safe access
		.rsta_busy						(					),
		.rstb_busy						(					),

		// AXI read control signals
		.s_axi_arid						(					),
		.s_axi_araddr					(					),
		.s_axi_arlen					(					),
		.s_axi_arsize					(					),
		.s_axi_arburst					(					),
		.s_axi_arvalid					(					),
		.s_axi_arready					(					),

		// AXI read data signals
		.s_axi_rid						(					),
		.s_axi_rdata					(					),
		.s_axi_rresp					(					),
		.s_axi_rlast					(					),
		.s_axi_rvalid					(					),
		.s_axi_rready					(					)
	);

endmodule
