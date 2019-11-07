module debug_AXI_reader #(
	parameter		// parameter for data buffer
					TOTAL_PACKAGE		=	416,
					DATA_DEPTH			=	16,
					DATA_DEPTH_INDEX	=	4,
					DATA_BYTE_SHIFT		=	5,
					DATA_BYTE_WIDTH		=	32,
	`ifndef			DATA_BIT_WIDTH
	`define			DATA_BIT_WIDTH		(DATA_BYTE_WIDTH << 3)
	`endif
					// parameter for uart_controller
					CLK_FRE				=	50,
					BAUD_RATE			=	115200,
					TX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH,
					RX_DATA_BYTE_WIDTH	=	DATA_BYTE_WIDTH
	`ifndef			TX_DATA_BIT_WIDTH
	`define			TX_DATA_BIT_WIDTH	(TX_DATA_BYTE_WIDTH << 3)
	`endif
	`ifndef			RX_DATA_BIT_WIDTH
	`define			RX_DATA_BIT_WIDTH	(RX_DATA_BYTE_WIDTH << 3)
	`endif
) (
	input				clk							,
	input				rst_n						,

	// start AXI read
	input				read_start					,
	input		[31:0]	AXI_reader_axi_araddr_start	,
	output	reg			transmit_done				,

	// uart signals
	input				uart_rx						,		// temp useless
	output				uart_tx						,

	// AXI signals
	// AXI read control signals
	output		[3:0]						AXI_reader_axi_arid			,
	output	reg	[31:0]						AXI_reader_axi_araddr		,
	output		[7:0]						AXI_reader_axi_arlen		,
	output		[2:0]						AXI_reader_axi_arsize		,
	output		[1:0]						AXI_reader_axi_arburst		,
	output	reg								AXI_reader_axi_arvalid		,
	input									AXI_reader_axi_arready		,

	// AXI read data signals
	input		[3:0]						AXI_reader_axi_rid			,
	input		[`DATA_BIT_WIDTH - 1:0]		AXI_reader_axi_rdata		,
	input		[1:0]						AXI_reader_axi_rresp		,
	input									AXI_reader_axi_rlast		,
	input									AXI_reader_axi_rvalid		,
	output	reg								AXI_reader_axi_rready		
);

	localparam			AXI_reader_IDLE		=	3'b000,
						AXI_reader_BURDELAY	=	3'b001,
						AXI_reader_RDFIRST	=	3'b010,
						AXI_reader_RD		=	3'b011,
						AXI_reader_SENDDATA	=	3'b100,
						AXI_reader_END		=	3'b101;

	// uart_controller signals
	wire [`TX_DATA_BIT_WIDTH - 1:0] tx_data;
	wire tx_vld;
	wire tx_rdy;
	wire [`RX_DATA_BIT_WIDTH - 1:0]	rx_data;
	wire rx_rdy;
	wire rx_ack = 1'b1;								// ignore all uart_rx

	// inner signals
	reg AXI_reader_delay;
	reg [31:0] start_araddr;
	reg [`DATA_BIT_WIDTH - 1:0] buffer[DATA_DEPTH - 1:0];
	(* mark_debug = "true" *)wire [`DATA_BIT_WIDTH - 1:0] debug_buffer[DATA_DEPTH - 1:0];
	genvar i;
	generate
	for (i = 0; i < DATA_DEPTH; i = i + 1)
		begin
		assign debug_buffer[i] = buffer[i];
		end
	endgenerate
	reg [DATA_DEPTH_INDEX - 1:0] senddata_cnt;
	reg senddata_cnt_flag;
	reg [9:0] package_cnt;
	reg [2:0] AXI_reader_state;
	reg [`TX_DATA_BIT_WIDTH - 1:0] AXI_reader_tx_data;
	reg AXI_reader_tx_vld;
	(* mark_debug = "true" *)wire [`DATA_BIT_WIDTH - 1:0] debug_AXI_reader_axi_rdata = AXI_reader_axi_rdata;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// state
			AXI_reader_state <= AXI_reader_IDLE;
			// inner signals
			senddata_cnt_flag <= 1'b0;
			AXI_reader_delay <= 1'b0;
			package_cnt <= 10'b0;
			senddata_cnt <= {DATA_DEPTH_INDEX{1'b0}};
			// for uart_controller
			AXI_reader_tx_data <= {`TX_DATA_BIT_WIDTH{1'b0}};
			AXI_reader_tx_vld <= 1'b0;
			// output
			transmit_done <= 1'b1;
			AXI_reader_axi_araddr <= 32'b0;
			AXI_reader_axi_arvalid <= 1'b0;
			AXI_reader_axi_rready <= 1'b0;
			end
		else
			begin
			case (AXI_reader_state)
				AXI_reader_IDLE:
					begin
					if (read_start)
						begin
						// state
						AXI_reader_state <= AXI_reader_BURDELAY;
						// inner signals
						AXI_reader_delay <= 1'b0;
						start_araddr <= AXI_reader_axi_araddr_start;
						package_cnt <= 10'b0;
						// for uart_controller
						AXI_reader_tx_data <= {`TX_DATA_BIT_WIDTH{1'b0}};
						AXI_reader_tx_vld <= 1'b0;
						// output
						transmit_done <= 1'b0;
						AXI_reader_axi_araddr <= AXI_reader_axi_araddr_start;
						AXI_reader_axi_arvalid <= 1'b1;
						AXI_reader_axi_rready <= 1'b0;
						end
					else
						begin
						// state
						AXI_reader_state <= AXI_reader_IDLE;
						// inner signals
						package_cnt <= 10'b0;
						senddata_cnt <= {DATA_DEPTH_INDEX{1'b0}};
						// for uart_controller
						AXI_reader_tx_data <= {`TX_DATA_BIT_WIDTH{1'b0}};
						AXI_reader_tx_vld <= 1'b0;
						// output
						transmit_done <= 1'b1;
						AXI_reader_axi_araddr <= 32'b0;
						AXI_reader_axi_arvalid <= 1'b0;
						AXI_reader_axi_rready <= 1'b0;
						end
					end
				AXI_reader_BURDELAY:
					begin
					// state
					AXI_reader_state <= AXI_reader_RDFIRST;
					end
				AXI_reader_RDFIRST:
					begin
					// for uart_controller
					AXI_reader_tx_data <= {`TX_DATA_BIT_WIDTH{1'b0}};
					AXI_reader_tx_vld <= 1'b0;
					// output
					AXI_reader_axi_araddr <= 32'b0;
					AXI_reader_axi_arvalid <= 1'b0;
					if (AXI_reader_axi_rvalid && (AXI_reader_axi_rid == 4'b0000))		// skip one.
						begin
						// state
						AXI_reader_state <= AXI_reader_RD;
						// output
						AXI_reader_axi_rready <= 1'b1;
						end
					else
						begin
						// state
						// do nothing
						// output
						AXI_reader_axi_rready <= 1'b0;
						end
					end
				AXI_reader_RD:
					begin
					// for uart_controller
					AXI_reader_tx_data <= {`TX_DATA_BIT_WIDTH{1'b0}};
					AXI_reader_tx_vld <= 1'b0;
					// output
					AXI_reader_axi_araddr <= 32'b0;
					AXI_reader_axi_arvalid <= 1'b0;
					if (AXI_reader_axi_rvalid && (AXI_reader_axi_rid == 4'b0000))
						begin
						// inner signals
						buffer[package_cnt[3:0]] <= AXI_reader_axi_rdata;
						package_cnt <= package_cnt + 1'b1;
						if (package_cnt[3:0] == 4'b1111)		// one transmit already end
							begin
							// state
							AXI_reader_state <= AXI_reader_SENDDATA;
							// inner signals
							senddata_cnt_flag <= 1'b0;
							AXI_reader_delay <= 1'b1;
							senddata_cnt <= {DATA_DEPTH_INDEX{1'b0}};
							// output
							AXI_reader_axi_rready <= 1'b1;
							end
						else
							begin
							// state
							// do nothing
							// output
							AXI_reader_axi_rready <= 1'b1;
							end
						end
					else
						begin
						// state
						// do nothing
						// output
						AXI_reader_axi_rready <= 1'b0;
						end
					end
				AXI_reader_SENDDATA:
					begin
					if (tx_rdy)						// TX ready
						begin
						if (AXI_reader_delay)
							begin
							// for uart_controller
							AXI_reader_tx_data <= buffer[senddata_cnt];
							AXI_reader_tx_vld <= 1'b1;
							// inner signals
							senddata_cnt_flag <= 1'b1;
							AXI_reader_delay <= 1'b0;
							senddata_cnt <= senddata_cnt + 1'b1;
							if (senddata_cnt == 4'b1111 && senddata_cnt_flag)	// transmit end
								begin
								if (package_cnt >= TOTAL_PACKAGE)
									begin
									// state
									AXI_reader_state <= AXI_reader_IDLE;
									// output
									transmit_done <= 1'b1;
									AXI_reader_axi_araddr <= 32'b0;
									AXI_reader_axi_arvalid <= 1'b0;
									AXI_reader_axi_rready <= 1'b0;
									end
								else
									begin
									// state
									AXI_reader_state <= AXI_reader_BURDELAY;
									// output
									AXI_reader_axi_araddr <= start_araddr + (package_cnt << DATA_BYTE_SHIFT);
									AXI_reader_axi_arvalid <= 1'b1;
									AXI_reader_axi_rready <= 1'b0;
									end
								end
							else
								begin
								// output
								AXI_reader_axi_araddr <= 32'b0;
								AXI_reader_axi_arvalid <= 1'b0;
								AXI_reader_axi_rready <= 1'b0;
								end
							end
						else				// due to 115200Hz
							begin
							// inner signals
							AXI_reader_delay <= 1'b1;
							// for uart_controller
							AXI_reader_tx_data <= 0;
							AXI_reader_tx_vld <= 1'b1;
							end
						end
					else
						begin
						// for uart_controller
						AXI_reader_tx_vld <= 1'b0;
						// output
						AXI_reader_axi_araddr <= 32'b0;
						AXI_reader_axi_arvalid <= 1'b0;
						AXI_reader_axi_rready <= 1'b0;
						end
					end
				default:
					begin
					// state
					AXI_reader_state <= AXI_reader_IDLE;
					// inner signals
					senddata_cnt_flag <= 1'b0;
					package_cnt <= 10'b0;
					senddata_cnt <= {DATA_DEPTH_INDEX{1'b0}};
					// for uart_controller
					AXI_reader_tx_data <= {`TX_DATA_BIT_WIDTH{1'b0}};
					AXI_reader_tx_vld <= 1'b0;
					// output
					transmit_done <= 1'b1;
					AXI_reader_axi_araddr <= 32'b0;
					AXI_reader_axi_arvalid <= 1'b0;
					AXI_reader_axi_rready <= 1'b0;
					end
			endcase
			end
		end

	// AXI read control signals
	assign AXI_reader_axi_arid = 4'b0000;
	assign AXI_reader_axi_arlen = 8'b00001111;		// 16
	assign AXI_reader_axi_arsize = 3'b101;
	assign AXI_reader_axi_arburst = 2'b01;

	// uart_controller
	uart_controller #(
		.CLK_FRE(CLK_FRE),				// 50MHz
		.BAUD_RATE(BAUD_RATE),			// 115200Hz
		.TX_DATA_BYTE_WIDTH(TX_DATA_BYTE_WIDTH),
		.RX_DATA_BYTE_WIDTH(RX_DATA_BYTE_WIDTH)
	) m_uart_controller (
		.clk			(clk			),
		.rst_n			(rst_n			),
		.uart_rx		(uart_rx		),
		.uart_tx		(uart_tx		),

		// inner data
		.tx_data		(tx_data		),		// data
		.tx_vld			(tx_vld			),		// start the transmit process
		.tx_rdy			(tx_rdy			),		// transmit process complete
		.rx_data		(rx_data		),		// data
		.rx_ack			(rx_ack			),		// data is received by receiver buffer					(RX_WAIT)
		.rx_rdy			(rx_rdy			)		// send signal to receiver buffer that data is ready
	);
	assign tx_data = AXI_reader_tx_data;
	assign tx_vld = AXI_reader_tx_vld;

endmodule
