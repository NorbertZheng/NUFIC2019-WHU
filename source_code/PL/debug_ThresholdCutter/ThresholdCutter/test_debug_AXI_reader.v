`timescale 1ns/1ns
module test_debug_AXI_reader #(
	// `define			SIM_ENABLE			1
	parameter		// parameter for data buffer
					TOTAL_PACKAGE		=	400,
					DATA_DEPTH			=	16,
					DATA_BYTE_SHIFT		=	5,
					DATA_BYTE_WIDTH		=	32,
	`ifndef			DATA_BIT_WIDTH
	`define			DATA_BIT_WIDTH		(DATA_BYTE_WIDTH << 3)
	`endif
					// parameter for uart_controller
					CLK_FRE				=	25,
					BAUD_RATE			=	115200,
					TX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH,
					RX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH
) (
	`ifndef SIM_ENABLE
	input			clk		,
	input			rst_n	,

	input			uart_rx	,
	output			uart_tx
	`endif
);

	`ifdef SIM_ENABLE
	reg clk, rst_n;
	`endif
	// debug_AXI_reader signals
	reg read_start;
	reg [31:0] AXI_reader_axi_araddr_start;
	wire uart_rx, uart_tx;
	wire [3:0] AXI_reader_axi_arid;
	wire [31:0]AXI_reader_axi_araddr;
	wire [7:0] AXI_reader_axi_arlen;
	wire [2:0] AXI_reader_axi_arsize;
	wire [1:0] AXI_reader_axi_arburst;
	wire AXI_reader_axi_arvalid, AXI_reader_axi_arready;
	wire [3:0] AXI_reader_axi_rid;
	wire [`DATA_BIT_WIDTH - 1:0] AXI_reader_axi_rdata;
	wire [1:0] AXI_reader_axi_rresp;
	wire AXI_reader_axi_rlast, AXI_reader_axi_rvalid, AXI_reader_axi_rready;
	// bram signals
	wire rsta_busy, rstb_busy;
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

	`ifdef SIM_ENABLE
	always # 50
		clk = ~clk;

	initial
		begin
		clk = 1'b0;
		rst_n = 1'b1;
		read_start = 1'b0;
		AXI_reader_axi_araddr_start = 32'b0;
		# 500;
		rst_n = 1'b0;
		# 500;
		rst_n = 1'b1;
		read_start = 1'b1;
		AXI_reader_axi_araddr_start = 32'b0;
		# 100;
		read_start = 1'b0;
		AXI_reader_axi_araddr_start = 32'b0;
		end
	assign sys_rst_n = rst_n;
	assign clk_50m = clk;
	`endif
	`ifndef SIM_ENABLE
	// PLL
	pll m_pll (
		.clk_50m		(clk_50m		),
		.reset			(rst_n			),
		.locked			(sys_rst_n		),
		.clk_in1		(clk			)
	);
	reg flag = 1'b0;
	always@ (posedge clk_50m)
		begin
		if (!sys_rst_n)
			begin
			read_start <= 1'b0;
			AXI_reader_axi_araddr_start <= 32'b0;
			end
		else
			begin
			if (flag == 1'b0)
				begin
				read_start <= 1'b1;
				AXI_reader_axi_araddr_start <= 32'b0;
				flag <= 1'b1;
				end
			else
				begin
				// do nothing
				read_start <= 1'b0;
				AXI_reader_axi_araddr_start <= 32'b0;
				end
			end
		end
	`endif

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
		.read_start						(read_start						),
		.AXI_reader_axi_araddr_start	(AXI_reader_axi_araddr_start	),

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
	assign s_aclk = clk_50m;
	assign s_aresetn = sys_rst_n;
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
	// set to 0
	assign s_axi_awvalid = 0;
	// assign s_axi_awready = 0;
	assign s_axi_awburst = 0;
	assign s_axi_awsize = 0;
	assign s_axi_awid = 0;
	assign s_axi_awlen = 0;
	assign s_axi_awaddr = 0;
	assign s_axi_wlast = 0;
	assign s_axi_wvalid = 0;
	// assign s_axi_wready = 0;
	assign s_axi_wstrb = 0;
	assign s_axi_wdata = 0;
	// assign s_axi_bvalid = 0;
	// assign s_axi_bresp = 0;
	// assign s_axi_bid = 0;

endmodule
