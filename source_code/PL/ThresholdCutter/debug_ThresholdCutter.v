module debug_ThresholdCutter #(
	parameter		// config enable
					CONFIG_EN							=	0,		// do not enable config
					// config
					CLK_FRE								=	40,		// 50MHz
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
					THRESHOLD							=	32'h0010_0000,	// threshold
					BLOCK_NUM_INDEX						=	3,				// 2 ** 6 == 64 blocks		// 16	// 8
					// parameter for package
					A_OFFSET							=	2,				// A's offset
					// parameter for square
					SQUARE_SRC_DATA_WIDTH				=	16,				// square src data width
					// parameter for preset-sequence
					PRESET_SEQUENCE						=	64'h00_01_02_03_04_05_06_07,	// 128'h00_01_02_03_04_05_06_07_08_09_00_01_02_03_04_05,
					// parameter for package
					PACKAGE_SIZE						=	11,
					PACKAGE_NUM							=	4,
					// parameter for debug_AXI_reader
					// parameter for data buffer
					TOTAL_PACKAGE		=	416,
					DATA_DEPTH			=	16,
					DATA_BYTE_SHIFT		=	5,
					DATA_BYTE_WIDTH		=	32,
	`ifndef			DATA_BIT_WIDTH
	`define			DATA_BIT_WIDTH		(DATA_BYTE_WIDTH << 3)
	`endif
					// parameter for uart_controller
					TX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH,
					RX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH
) (
	input									clk					,
	input									rst_n				,

	// uart
	input									uart_rx				,		// temp useless
	output									uart_tx				,

	// BlueTooth_Config
	input									BlueTooth_State		,
	output									BlueTooth_Key		,
	output									BlueTooth_Rxd		,
	input									BlueTooth_Txd		,
	output									BlueTooth_Vcc		,
	output									BlueTooth_Gnd		
);

	// PLL signals
	wire clk_50m, sys_rst_n;

	// debug_AXI_reader signals
	// start AXI read
	wire debug_read_start;
	wire [31:0] debug_AXI_reader_axi_araddr_start;
	// AXI signals
	// AXI read control signals
	wire [3:0] AXI_reader_axi_arid;
	wire [31:0] AXI_reader_axi_araddr;
	wire [7:0] AXI_reader_axi_arlen;
	wire [2:0] AXI_reader_axi_arsize;
	wire [1:0] AXI_reader_axi_arburst;
	wire AXI_reader_axi_arvalid, AXI_reader_axi_arready;

	// AXI read data signals
	wire [3:0] AXI_reader_axi_rid;
	wire [`DATA_BIT_WIDTH - 1:0] AXI_reader_axi_rdata;
	wire [1:0] AXI_reader_axi_rresp;
	wire AXI_reader_axi_rlast, AXI_reader_axi_rvalid, AXI_reader_axi_rready;

	// ThresholdCutter signals
	// ThresholdCutterWindow signals
	wire [WINDOW_DEPTH - 1:0] ThresholdCutterWindow_flag_o;
	wire AXI_reader_read_start;
	wire [31:0] AXI_reader_axi_araddr_start;
	// AXI RAM signals
	// ram safe access
	wire rsta_busy, rstb_busy;
	// AXI read control signals
	wire [3:0] s_axi_arid;
	wire [31:0] s_axi_araddr;
	wire [7:0] s_axi_arlen;
	wire [2:0] s_axi_arsize;
	wire [1:0] s_axi_arburst;
	wire s_axi_arvalid, s_axi_arready;
	// AXI read data signals
	wire [3:0] s_axi_rid;
	wire [255:0] s_axi_rdata;
	wire [1:0] s_axi_rresp;
	wire s_axi_rlast, s_axi_rvalid, s_axi_rready;

	// PLL
	pll m_pll (
		.clk_50m		(clk_50m		),
		.reset			(rst_n			),
		.locked			(sys_rst_n		),
		.clk_in1		(clk			)
	);

	// debug_AXI_reader
	debug_AXI_reader #(
		// parameter for data buffer
		.TOTAL_PACKAGE(TOTAL_PACKAGE),
		.DATA_DEPTH(DATA_DEPTH),
		.DATA_BYTE_SHIFT(DATA_BYTE_SHIFT),
		.DATA_BYTE_WIDTH(DATA_BYTE_WIDTH),
		// parameter for uart_controller
		.CLK_FRE(CLK_FRE),
		.BAUD_RATE(BAUD_RATE),
		.TX_DATA_BYTE_WIDTH(TX_DATA_BYTE_WIDTH),
		.RX_DATA_BYTE_WIDTH(RX_DATA_BYTE_WIDTH)
	) m_debug_AXI_reader (
		.clk							(clk_50m						),
		.rst_n							(sys_rst_n						),

		// start AXI read
		.read_start						(debug_read_start					),
		.AXI_reader_axi_araddr_start	(debug_AXI_reader_axi_araddr_start	),

		// uart signals
		.uart_rx						(uart_rx						),		// temp useless
		.uart_tx						(uart_tx						),

		// AXI signals
		// AXI read control signals
		.AXI_reader_axi_arid			(AXI_reader_axi_arid			),
		.AXI_reader_axi_araddr			(AXI_reader_axi_araddr			),
		.AXI_reader_axi_arlen			(AXI_reader_axi_arlen			),
		.AXI_reader_axi_arsize			(AXI_reader_axi_arsize			),
		.AXI_reader_axi_arburst			(AXI_reader_axi_arburst			),
		.AXI_reader_axi_arvalid			(AXI_reader_axi_arvalid			),
		.AXI_reader_axi_arready			(AXI_reader_axi_arready			),

		// AXI read data signals
		.AXI_reader_axi_rid				(AXI_reader_axi_rid				),
		.AXI_reader_axi_rdata			(AXI_reader_axi_rdata			),
		.AXI_reader_axi_rresp			(AXI_reader_axi_rresp			),
		.AXI_reader_axi_rlast			(AXI_reader_axi_rlast			),
		.AXI_reader_axi_rvalid			(AXI_reader_axi_rvalid			),
		.AXI_reader_axi_rready			(AXI_reader_axi_rready			)
	);
	assign debug_read_start = AXI_reader_read_start;
	assign debug_AXI_reader_axi_araddr_start = AXI_reader_axi_araddr_start;

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
	) m_ThresholdCutter (
		.clk							(clk_50m						),
		.rst_n							(sys_rst_n						),

		// BlueTooth_Config
		.BlueTooth_State				(BlueTooth_State				),
		.BlueTooth_Key					(BlueTooth_Key					),
		.BlueTooth_Rxd					(BlueTooth_Rxd					),
		.BlueTooth_Txd					(BlueTooth_Txd					),
		.BlueTooth_Vcc					(BlueTooth_Vcc					),
		.BlueTooth_Gnd					(BlueTooth_Gnd					),

		// ThresholdCutterWindow signals
		.ThresholdCutterWindow_flag_o	(ThresholdCutterWindow_flag_o	),

		.AXI_reader_read_start			(AXI_reader_read_start					),
		.AXI_reader_axi_araddr_start	(AXI_reader_axi_araddr_start			),

		// AXI RAM signals
		// ram safe access
		.rsta_busy						(rsta_busy						),
		.rstb_busy						(rstb_busy						),

		// AXI read control signals
		.s_axi_arid						(s_axi_arid						),
		.s_axi_araddr					(s_axi_araddr					),
		.s_axi_arlen					(s_axi_arlen					),
		.s_axi_arsize					(s_axi_arsize					),
		.s_axi_arburst					(s_axi_arburst					),
		.s_axi_arvalid					(s_axi_arvalid					),
		.s_axi_arready					(s_axi_arready					),

		// AXI read data signals
		.s_axi_rid						(s_axi_rid						),
		.s_axi_rdata					(s_axi_rdata					),
		.s_axi_rresp					(s_axi_rresp					),
		.s_axi_rlast					(s_axi_rlast					),
		.s_axi_rvalid					(s_axi_rvalid					),
		.s_axi_rready					(s_axi_rready					)
	);
	assign s_axi_arid = AXI_reader_axi_arid;
	assign s_axi_araddr = AXI_reader_axi_araddr;
	assign s_axi_arlen = AXI_reader_axi_arlen;
	assign s_axi_arsize = AXI_reader_axi_arsize;
	assign s_axi_arburst = AXI_reader_axi_arburst;
	assign s_axi_arvalid = AXI_reader_axi_arvalid;
	assign AXI_reader_axi_arready = s_axi_arready;
	assign AXI_reader_axi_rid = s_axi_rid;
	assign AXI_reader_axi_rdata = s_axi_rdata;
	assign AXI_reader_axi_rresp = s_axi_rresp;
	assign AXI_reader_axi_rlast = s_axi_rlast;
	assign AXI_reader_axi_rvalid = s_axi_rvalid;
	assign s_axi_rready = AXI_reader_axi_rready;

endmodule
