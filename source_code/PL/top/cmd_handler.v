module cmd_handler #(
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
					RESPONSE_FIFO_DATA_DEPTH_INDEX		=	10,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					// uart connected with PC
					PC_BAUD_RATE						=	115200	// 115200Hz
) (
	input									clk					,
	input									rst_n				,
	input									uart_rx				,
	output									uart_tx				,
	// BlueTooth_Config
	input									BlueTooth_State		,
	output									BlueTooth_Key		,
	output									BlueTooth_Rxd		,
	input									BlueTooth_Txd		,
	output									BlueTooth_Vcc		,
	output									BlueTooth_Gnd		
);

	localparam			RX_IDLE		=	2'b00,
						RX_WRDATA	=	2'b01,
						RX_END		=	2'b10,
						TX_IDLE		=	2'b00,
						TX_RDDATA	=	2'b01,
						TX_TRANSMIT	=	2'b10,
						TX_WAIT		=	2'b11;

	// PLL signals
	wire clk_50m, sys_rst_n;

	// uart_controller8bit signals
	reg tx_vld, rx_ack;
	wire tx_rdy, rx_rdy;
	reg [7:0] tx_data;
	wire [7:0] rx_data;

	// BlueToothController signals
	reg BlueTooth_request_FIFO_data_i_vld, BlueTooth_response_FIFO_r_en;
	wire BlueTooth_request_FIFO_data_i_rdy, BlueTooth_request_FIFO_full, BlueTooth_request_FIFO_empty;
	wire BlueTooth_response_FIFO_data_o_vld, BlueTooth_response_FIFO_full, BlueTooth_response_FIFO_empty;
	wire [REQUEST_FIFO_DATA_DEPTH_INDEX - 1:0] BlueTooth_request_FIFO_surplus;
	wire [RESPONSE_FIFO_DATA_DEPTH_INDEX - 1:0] BlueTooth_response_FIFO_surplus;
	reg [REQUEST_FIFO_DATA_WIDTH - 1:0] BlueTooth_request_FIFO_data_i;
	wire [RESPONSE_FIFO_DATA_WIDTH - 1:0] BlueTooth_response_FIFO_data_o;
	// for debug
	reg BlueTooth_State_reg;
	always@ (posedge clk_50m)
		BlueTooth_State_reg <= BlueTooth_State;
	(* mark_debug = "true" *)wire debug_BlueTooth_State = BlueTooth_State_reg;

	// receive request(RX)
	reg [1:0] cmd_handler_rx_state;
	always@ (posedge clk_50m)
		begin
		if (!sys_rst_n)
			begin
			// state
			cmd_handler_rx_state <= RX_IDLE;
			// request FIFO signals
			BlueTooth_request_FIFO_data_i_vld <= 1'b0;
			BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
			// uart_controller8bit signals
			rx_ack <= 1'b0;
			end
		else
			begin
			case (cmd_handler_rx_state)
				RX_IDLE:
					begin
					if (rx_rdy)							// receive data
						begin
						// state
						cmd_handler_rx_state <= RX_WRDATA;
						// request FIFO signals
						BlueTooth_request_FIFO_data_i_vld <= 1'b1;
						BlueTooth_request_FIFO_data_i <= rx_data;
						// uart_controller8bit signals
						rx_ack <= 1'b0;
						end
					else
						begin
						// state
						cmd_handler_rx_state <= RX_IDLE;
						// request FIFO signals
						BlueTooth_request_FIFO_data_i_vld <= 1'b0;
						BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
						// uart_controller8bit signals
						rx_ack <= 1'b0;
						end
					end
				RX_WRDATA:
					begin
					// request FIFO signals
					BlueTooth_request_FIFO_data_i_vld <= 1'b0;
					BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
					if (BlueTooth_request_FIFO_data_i_rdy)			// data is accepted by FIFO
						begin
						// state
						cmd_handler_rx_state <= RX_END;
						// uart_controller8bit signals
						rx_ack <= 1'b1;
						end
					else
						begin
						// uart_controller8bit signals
						rx_ack <= 1'b0;
						end
					end
				RX_END:
					begin
					// state
					cmd_handler_rx_state <= RX_IDLE;
					// request FIFO signals
					BlueTooth_request_FIFO_data_i_vld <= 1'b0;
					BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
					// uart_controller8bit signals
					rx_ack <= 1'b0;
					end
				default:
					begin
					// state
					cmd_handler_rx_state <= RX_IDLE;
					// request FIFO signals
					BlueTooth_request_FIFO_data_i_vld <= 1'b0;
					BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
					// uart_controller8bit signals
					rx_ack <= 1'b0;
					end
			endcase
			end
		end

	// send response(TX)
	reg [1:0] cmd_handler_tx_state;
	always@ (posedge clk_50m)
		begin
		if (!sys_rst_n)
			begin
			// state
			cmd_handler_tx_state <= TX_IDLE;
			// response FIFO signals
			BlueTooth_response_FIFO_r_en <= 1'b0;
			// uart_controller8bit signals
			tx_vld <= 1'b0;
			tx_data <= 8'b0;
			end
		else
			begin
			case (cmd_handler_tx_state)
				TX_IDLE:
					begin
					if (!BlueTooth_response_FIFO_empty)			// request FIFO is not empty
						begin
						// state
						cmd_handler_tx_state <= TX_RDDATA;
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b1;
						// uart_controller8bit signals
						tx_vld <= 1'b0;
						tx_data <= 8'b0;
						end
					else
						begin
						// state
						cmd_handler_tx_state <= TX_IDLE;
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b0;
						// uart_controller8bit signals
						tx_vld <= 1'b0;
						tx_data <= 8'b0;
						end
					end
				TX_RDDATA:											// at the same posedge clk, FIFO is reading data
					begin
					// state
					cmd_handler_tx_state <= TX_TRANSMIT;
					// response FIFO signals
					BlueTooth_response_FIFO_r_en <= 1'b0;
					// uart_controller8bit signals
					tx_vld <= 1'b0;
					tx_data <= 8'b0;
					end
				TX_TRANSMIT:
					begin
					// response FIFO signals
					BlueTooth_response_FIFO_r_en <= 1'b0;
					if (BlueTooth_response_FIFO_data_o_vld)			// data is valid
						begin
						// state
						cmd_handler_tx_state <= TX_WAIT;
						// uart_controller8bit signals
						tx_vld <= 1'b1;
						tx_data <= BlueTooth_response_FIFO_data_o;
						end
					else
						begin
						// state
						cmd_handler_tx_state <= TX_IDLE;
						// uart_controller8bit signals
						tx_vld <= 1'b0;
						tx_data <= 8'b0;
						end
					end
				TX_WAIT:
					begin
					if (tx_rdy)							// transmission complete
						begin
						// state
						cmd_handler_tx_state <= TX_IDLE;
						// response FIFO signals
						BlueTooth_response_FIFO_r_en <= 1'b0;
						// uart_controller8bit signals
						tx_vld <= 1'b0;
						tx_data <= 8'b0;
						end
					else											// wait for transmission complete
						begin
						// uart_controller8bit signals
						tx_vld <= 1'b0;
						tx_data <= 8'b0;
						end
					end
				default:
					begin
					// state
					cmd_handler_tx_state <= TX_IDLE;
					// response FIFO signals
					BlueTooth_response_FIFO_r_en <= 1'b0;
					// uart_controller8bit signals
					tx_vld <= 1'b0;
					tx_data <= 8'b0;
					end
			endcase
			end
		end

	// PLL
	pll m_pll (
		.clk_50m		(clk_50m		),
		.reset			(rst_n			),
		.locked			(sys_rst_n		),
		.clk_in1		(clk			)
	);

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

	// uart_controller8bit
	uart_controller8bit #(
		.CLK_FRE(CLK_FRE),			// 50MHz
		.BAUD_RATE(PC_BAUD_RATE)	// 115200Hz
	) m_uart_controller8bit (
		.clk			(clk_50m		),
		.rst_n			(sys_rst_n		),
		.uart_rx		(uart_rx	),
		.uart_tx		(uart_tx	),

		// inner data
		.tx_data		(tx_data	),		// data
		.tx_vld			(tx_vld		),		// start the transmit process
		.tx_rdy			(tx_rdy		),		// transmit process complete
		.rx_data		(rx_data	),		// data
		.rx_ack			(rx_ack		),		// data is received by receiver buffer					(RX_WAIT)
		.rx_rdy			(rx_rdy		)		// send signal to receiver buffer that data is ready
	);

endmodule
