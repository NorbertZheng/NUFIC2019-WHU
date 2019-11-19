`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/07 12:50:10
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top #(
	parameter		AXIS_DATA_WIDTH		=	256		,
					AXIS_DATA_KEEP		=	32		,
					AXIS_DATA_DEPTH		=	400		,
					// config enable
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
					THRESHOLD							=	32'h0008_0000,	// threshold
					G_THRESHOLD							=	32'h0040_0000,
					BLOCK_NUM_INDEX						=	0,				// 2 ** 6 == 64 blocks		// 16	// 8
					// parameter for package
					A_OFFSET							=	2,				// A's offset
					// parameter for square
					SQUARE_SRC_DATA_WIDTH				=	16,				// square src data width
					// parameter for preset-sequence
					PRESET_SEQUENCE_LENG				=	8,
					PRESET_SEQUENCE						=	8'h00,			// 64'h00_01_02_03_04_05_06_07,	// 128'h00_01_02_03_04_05_06_07_08_09_00_01_02_03_04_05,
					// parameter for package
					PACKAGE_SIZE						=	11,
					PACKAGE_NUM							=	4,
					// parameter for debug_AXI_reader
					// parameter for data buffer
					TOTAL_PACKAGE		=	816,		// 416,
					DATA_DEPTH			=	16,
					DATA_DEPTH_INDEX	=	4,
					DATA_BYTE_SHIFT		=	5,
					DATA_BYTE_WIDTH		=	32,
	`ifndef			DATA_BIT_WIDTH
	`define			DATA_BIT_WIDTH		(DATA_BYTE_WIDTH << 3)
	`endif
					// parameter for uart_controller
					TX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH,
					RX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH,
					
					// parameter for read_intr_generator
					INTR_PERIOD			=	1 * 1000 * 1000,
					INTR_CNT_WIDTH		=	21
	`ifndef PS_ENABLE
	`define			PS_ENABLE			1
	`endif
) (
	inout			[14:0]		DDR_addr				,
	inout			[2:0]		DDR_ba					,
	inout						DDR_cas_n				,
	inout						DDR_ck_n				,
	inout						DDR_ck_p				,
	inout						DDR_cke					,
	inout						DDR_cs_n				,
	inout			[3:0]		DDR_dm					,
	inout			[31:0]		DDR_dq					,
	inout			[3:0]		DDR_dqs_n				,
	inout			[3:0]		DDR_dqs_p				,
	inout						DDR_odt					,
	inout						DDR_ras_n				,
	inout						DDR_reset_n				,
	inout						DDR_we_n				,
	inout						FIXED_IO_ddr_vrn		,
	inout						FIXED_IO_ddr_vrp		,
	inout			[53:0]		FIXED_IO_mio			,
	inout						FIXED_IO_ps_clk			,
	inout						FIXED_IO_ps_porb		,
	inout						FIXED_IO_ps_srstb		,
	// input			[255:0]		S_AXIS_0_tdata			,
	// input			[31:0]		S_AXIS_0_tkeep			,
	// input						S_AXIS_0_tlast			,
	// output						S_AXIS_0_tready			,
	// input						S_AXIS_0_tvalid			,
	// output						clk_50M_0				,
	// output						locked_0				

	// BlueTooth_Config
	input									BlueTooth_State		,
	output									BlueTooth_Key		,
	output									BlueTooth_Rxd		,
	input									BlueTooth_Txd		,
	output									BlueTooth_Vcc		,
	output									BlueTooth_Gnd		
);

	// system_wrapper signals
	// clock wizid signals
	wire clk_50M_0, locked_0;
	// S_AXIS signals
	wire S_AXIS_0_tlast, S_AXIS_0_tready, S_AXIS_0_tvalid;
	wire [31:0] S_AXIS_0_tkeep;
	wire [255:0] S_AXIS_0_tdata;
	// GPIO signals
	wire GPIO_0_tri_i;

	// read_intr_generator signals
	wire read_intr_generator_clk, read_intr_generator_rst_n;
	wire read_intr_generator_read_intr, read_intr_generator_read_start_intr;

	// AXIS_data_transmitter signals
	wire AXIS_data_transmitter_clk, AXIS_data_transmitter_rst_n;
	wire AXIS_data_transmitter_transmit_vld, AXIS_data_transmitter_transmit_last, AXIS_data_transmitter_transmit_rdy;
	wire [AXIS_DATA_WIDTH - 1:0] AXIS_data_transmitter_transmit_data;
	wire [AXIS_DATA_WIDTH - 1:0] AXIS_data_transmitter_AXIS_tdata;
	wire [AXIS_DATA_KEEP - 1:0] AXIS_data_transmitter_AXIS_tkeep;
	wire AXIS_data_transmitter_AXIS_tlast, AXIS_data_transmitter_AXIS_tready, AXIS_data_transmitter_AXIS_tvalid;
	(* mark_debug = "true" *)wire [AXIS_DATA_WIDTH - 1:0] debug_AXIS_data_transmitter_AXIS_tdata = AXIS_data_transmitter_AXIS_tdata;
	(* mark_debug = "true" *)wire [AXIS_DATA_KEEP - 1:0] debug_AXIS_data_transmitter_AXIS_tkeep = AXIS_data_transmitter_AXIS_tkeep;
	(* mark_debug = "true" *)wire debug_AXIS_data_transmitter_AXIS_tlast = AXIS_data_transmitter_AXIS_tlast;
	(* mark_debug = "true" *)wire debug_AXIS_data_transmitter_AXIS_tready = AXIS_data_transmitter_AXIS_tready;
	(* mark_debug = "true" *)wire debug_AXIS_data_transmitter_AXIS_tvalid = AXIS_data_transmitter_AXIS_tvalid;

	// debug_ThresholdCutter signals
	wire PL_clk, PL_rst_n;
	wire PL_transmit_vld, PL_transmit_last, PL_transmit_rdy, PL_read_start_intr;
	wire [AXIS_DATA_WIDTH - 1:0] PL_transmit_data;

	// AXIS_data_transmitter
	AXIS_data_transmitter #(
		.AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
		.AXIS_DATA_KEEP(AXIS_DATA_KEEP),
		.AXIS_DATA_DEPTH(AXIS_DATA_DEPTH)
	) m_AXIS_data_transmitter (
		.clk									(AXIS_data_transmitter_clk			),
		.rst_n									(AXIS_data_transmitter_rst_n		),

		.transmit_vld							(AXIS_data_transmitter_transmit_vld	),
		.transmit_data							(AXIS_data_transmitter_transmit_data),
		.transmit_last							(AXIS_data_transmitter_transmit_last),
		.transmit_rdy							(AXIS_data_transmitter_transmit_rdy	),

		.AXIS_data_transmitter_AXIS_tdata		(AXIS_data_transmitter_AXIS_tdata	),
		.AXIS_data_transmitter_AXIS_tkeep		(AXIS_data_transmitter_AXIS_tkeep	),
		.AXIS_data_transmitter_AXIS_tlast		(AXIS_data_transmitter_AXIS_tlast	),
		.AXIS_data_transmitter_AXIS_tready		(AXIS_data_transmitter_AXIS_tready	),
		.AXIS_data_transmitter_AXIS_tvalid		(AXIS_data_transmitter_AXIS_tvalid	)
	);

	// read_intr_generator
	read_intr_generator #(
		.INTR_PERIOD(INTR_PERIOD),
		.INTR_CNT_WIDTH(INTR_CNT_WIDTH)
	) m_read_intr_generator (
		.clk					(read_intr_generator_clk				),
		.rst_n					(read_intr_generator_rst_n				),

		.read_start_intr		(read_intr_generator_read_start_intr	),
		.read_intr				(read_intr_generator_read_intr			)
	);
	assign read_intr_generator_clk = clk_50M_0;
	assign read_intr_generator_rst_n = locked_0;
	assign read_intr_generator_read_start_intr = PL_read_start_intr;

	// system_wrapper
	system_wrapper m_system_wrapper(.DDR_addr(DDR_addr),
		.DDR_ba(DDR_ba),		
		.DDR_cas_n(DDR_cas_n),
		.DDR_ck_n(DDR_ck_n),
		.DDR_ck_p(DDR_ck_p),
		.DDR_cke(DDR_cke),
		.DDR_cs_n(DDR_cs_n),
		.DDR_dm(DDR_dm),
		.DDR_dq(DDR_dq),
		.DDR_dqs_n(DDR_dqs_n),
		.DDR_dqs_p(DDR_dqs_p),
		.DDR_odt(DDR_odt),
		.DDR_ras_n(DDR_ras_n),
		.DDR_reset_n(DDR_reset_n),
		.DDR_we_n(DDR_we_n),
		.FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
		.FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
		.FIXED_IO_mio(FIXED_IO_mio),
		.FIXED_IO_ps_clk(FIXED_IO_ps_clk),
		.FIXED_IO_ps_porb(FIXED_IO_ps_porb),
		.FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
		.GPIO_0_tri_i(GPIO_0_tri_i),
		.S_AXIS_0_tdata(S_AXIS_0_tdata),
		.S_AXIS_0_tkeep(S_AXIS_0_tkeep),
		.S_AXIS_0_tlast(S_AXIS_0_tlast),
		.S_AXIS_0_tready(S_AXIS_0_tready),
		.S_AXIS_0_tvalid(S_AXIS_0_tvalid),
		.clk_50M_0(clk_50M_0),
		.locked_0(locked_0)
	);
	assign AXIS_data_transmitter_clk = clk_50M_0;
	assign AXIS_data_transmitter_rst_n = locked_0;
	assign AXIS_data_transmitter_AXIS_tready = S_AXIS_0_tready;
	assign GPIO_0_tri_i = read_intr_generator_read_intr;
	assign S_AXIS_0_tdata = AXIS_data_transmitter_AXIS_tdata;
	assign S_AXIS_0_tkeep = AXIS_data_transmitter_AXIS_tkeep;
	assign S_AXIS_0_tlast = AXIS_data_transmitter_AXIS_tlast;
	assign S_AXIS_0_tvalid = AXIS_data_transmitter_AXIS_tvalid;

	// debug_ThresholdCutter
	debug_ThresholdCutter #(
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
		.G_THRESHOLD(G_THRESHOLD),
		.BLOCK_NUM_INDEX(BLOCK_NUM_INDEX),				// 2 ** 6 == 64 blocks		// 16	// 8
		// parameter for package
		.A_OFFSET(A_OFFSET),				// A's offset
		// parameter for square
		.SQUARE_SRC_DATA_WIDTH(SQUARE_SRC_DATA_WIDTH),				// square src data width
		// parameter for preset-sequence
		.PRESET_SEQUENCE_LENG(PRESET_SEQUENCE_LENG),
		.PRESET_SEQUENCE(PRESET_SEQUENCE),			// 64'h00_01_02_03_04_05_06_07,	// 128'h00_01_02_03_04_05_06_07_08_09_00_01_02_03_04_05,
		// parameter for package
		.PACKAGE_SIZE(PACKAGE_SIZE),
		.PACKAGE_NUM(PACKAGE_NUM),
		// parameter for debug_AXI_reader
		// parameter for data buffer
		.TOTAL_PACKAGE(TOTAL_PACKAGE),
		.DATA_DEPTH(DATA_DEPTH),
		.DATA_DEPTH_INDEX(DATA_DEPTH_INDEX),
		.DATA_BYTE_SHIFT(DATA_BYTE_SHIFT),
		.DATA_BYTE_WIDTH(DATA_BYTE_WIDTH),
		// parameter for uart_controller
		.TX_DATA_BYTE_WIDTH(TX_DATA_BYTE_WIDTH),
		.RX_DATA_BYTE_WIDTH(RX_DATA_BYTE_WIDTH),
		// parameter for AXIS
		.AXIS_DATA_WIDTH(AXIS_DATA_WIDTH)
	) m_debug_ThresholdCutter (
		.clk				(PL_clk					),
		.rst_n				(PL_rst_n				),

		// for AXIS
		// `ifdef PS_ENABLE
		.transmit_vld		(PL_transmit_vld			),
		.transmit_data		(PL_transmit_data			),
		.transmit_last		(PL_transmit_last			),
		.transmit_rdy		(PL_transmit_rdy			),
		.read_start_intr	(PL_read_start_intr			),
		// `endif

		// BlueTooth_Config
		.BlueTooth_State	(BlueTooth_State		),
		.BlueTooth_Key		(BlueTooth_Key			),
		.BlueTooth_Rxd		(BlueTooth_Rxd			),
		.BlueTooth_Txd		(BlueTooth_Txd			),
		.BlueTooth_Vcc		(BlueTooth_Vcc			),
		.BlueTooth_Gnd		(BlueTooth_Gnd			)
	);
	assign PL_clk = clk_50M_0;
	assign PL_rst_n = locked_0;
	assign PL_transmit_rdy = AXIS_data_transmitter_transmit_rdy;
	assign AXIS_data_transmitter_transmit_vld = PL_transmit_vld;
	assign AXIS_data_transmitter_transmit_data = PL_transmit_data;
	assign AXIS_data_transmitter_transmit_last = PL_transmit_last;

endmodule
