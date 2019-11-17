module sim_BlueToothController #(
	parameter		// config enable
					CONFIG_EN							=	1,		// do not enable config
					// config
					CLK_FRE								=	50,		// 50MHz
					BAUD_RATE							=	9600,	// 9600Hz (4800, 19200, 38400, 57600, 115200, 38400...)
					STOP_BIT							=	0,		// 0 : 1-bit stop-bit, 1 : 2-bit stop-bit
					CHECK_BIT							=	0,		// 0 : no check-bit, 1 : odd, 2 : even
					// default	9600	0	0
					// granularity
					REQUEST_FIFO_DATA_WIDTH				=	8,		// the bit width of data we stored in the FIFO
					REQUEST_FIFO_DATA_DEPTH_INDEX		=	5,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					RESPONSE_FIFO_DATA_WIDTH			=	8,		// the bit width of data we stored in the FIFO
					RESPONSE_FIFO_DATA_DEPTH_INDEX		=	5,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					// parameter for uart
					TX_DATA_BYTE_WIDTH					=	11,		// 11 bytes to transmit
					RX_DATA_BYTE_WIDTH					=	11		// 11 bytes to receive
) (
	input												clk,
	input												rst_n,

	// request FIFO signals
	input		[REQUEST_FIFO_DATA_WIDTH - 1:0]			cmd_handler_BlueTooth_request_FIFO_data_i,
	input												cmd_handler_BlueTooth_request_FIFO_data_i_vld,
	output												cmd_handler_BlueTooth_request_FIFO_data_i_rdy,
	// for debug
	output												cmd_handler_BlueTooth_request_FIFO_full,
	output												cmd_handler_BlueTooth_request_FIFO_empty,
	output		[REQUEST_FIFO_DATA_DEPTH_INDEX - 1:0]	cmd_handler_BlueTooth_request_FIFO_surplus,

	// response FIFO signals
	input												cmd_handler_BlueTooth_response_FIFO_r_en,
	output		[RESPONSE_FIFO_DATA_WIDTH - 1:0]		cmd_handler_BlueTooth_response_FIFO_data_o,
	output												cmd_handler_BlueTooth_response_FIFO_data_o_vld,
	// for debug
	output												cmd_handler_BlueTooth_response_FIFO_full,
	output												cmd_handler_BlueTooth_response_FIFO_empty,
	output		[RESPONSE_FIFO_DATA_DEPTH_INDEX - 1:0]	cmd_handler_BlueTooth_response_FIFO_surplus,

	// sim_BlueTooth signals
	input		[`TX_DATA_BIT_WIDTH - 1:0]				tx_data		,		// data
	input												tx_vld		,		// start the transmit process
	output												tx_rdy		,		// transmit process complete
	output		[`RX_DATA_BIT_WIDTH - 1:0]				rx_data		,		// data
	input												rx_ack		,		// data is received by receiver buffer					(RX_WAIT)
	output												rx_rdy				// send signal to receiver buffer that data is ready
);

	// BlueToothController signals
	wire BlueTooth_State, BlueTooth_Key, BlueTooth_Rxd;
	wire BlueTooth_Txd, BlueTooth_Vcc, BlueTooth_Gnd;

	// sim_BlueTooth signals
	wire uart_rx, uart_tx;

	// sim_BlueTooth
	sim_BlueTooth #(
		// config
		.CLK_FRE(CLK_FRE),		// 50MHz
		.BAUD_RATE(BAUD_RATE),	// 9600Hz (4800, 19200, 38400, 57600, 115200, 38400...)
		.TX_DATA_BYTE_WIDTH(TX_DATA_BYTE_WIDTH),		// 11 bytes to transmit
		.RX_DATA_BYTE_WIDTH(RX_DATA_BYTE_WIDTH)		// 11 bytes to receive
	) (
		.clk				(clk			),
		.rst_n				(rst_n			),

		// uart signals
		.uart_rx			(uart_rx		),
		.uart_tx			(uart_tx		),		// should connect with BlueTooth_Txd in BlueToothController.v

		// inner data
		.tx_data			(tx_data		),		// data
		.tx_vld				(tx_vld			),		// start the transmit process
		.tx_rdy				(tx_rdy			),		// transmit process complete
		.rx_data			(rx_data		),		// data
		.rx_ack				(rx_ack			),		// data is received by receiver buffer					(RX_WAIT)
		.rx_rdy				(rx_rdy			)		// send signal to receiver buffer that data is ready
	);

	// BlueToothController
	BlueToothController #(
		// config enable
		.CONFIG_EN(CONFIG_EN),												// do not enable config
		// config
		.CLK_FRE(CLK_FRE),													// 50MHz
		.BAUD_RATE(BAUD_RATE),												// 9600Hz (4800, 19200, 38400, 57600, 115200, 38400...)
		.STOP_BIT(STOP_BIT),												// 0 : 1-bit stop-bit, 1 : 2-bit stop-bit
		.CHECK_BIT(CHECK_BIT),												// 0 : no check-bit, 1 : odd, 2 : even
		// default	9600	0	0
		// granularity
		.REQUEST_FIFO_DATA_WIDTH(REQUEST_FIFO_DATA_WIDTH),					// the bit width of data we stored in the FIFO
		.REQUEST_FIFO_DATA_DEPTH_INDEX(REQUEST_FIFO_DATA_DEPTH_INDEX),		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
		.RESPONSE_FIFO_DATA_WIDTH(RESPONSE_FIFO_DATA_WIDTH),				// the bit width of data we stored in the FIFO
		.RESPONSE_FIFO_DATA_DEPTH_INDEX(RESPONSE_FIFO_DATA_DEPTH_INDEX)		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
	) m_BlueToothController (
		.clk												(clk											),
		.rst_n												(rst_n											),

		// BlueTooth_Config
		.BlueTooth_State									(BlueTooth_State								),
		.BlueTooth_Key										(BlueTooth_Key									),
		.BlueTooth_Rxd										(BlueTooth_Rxd									),
		.BlueTooth_Txd										(BlueTooth_Txd									),
		.BlueTooth_Vcc										(BlueTooth_Vcc									),
		.BlueTooth_Gnd										(BlueTooth_Gnd									),

		// request FIFO signals
		.cmd_handler_BlueTooth_request_FIFO_data_i			(cmd_handler_BlueTooth_request_FIFO_data_i		),
		.cmd_handler_BlueTooth_request_FIFO_data_i_vld		(cmd_handler_BlueTooth_request_FIFO_data_i_vld	),
		.cmd_handler_BlueTooth_request_FIFO_data_i_rdy		(cmd_handler_BlueTooth_request_FIFO_data_i_rdy	),
		// for debug
		.cmd_handler_BlueTooth_request_FIFO_full			(cmd_handler_BlueTooth_request_FIFO_full		),
		.cmd_handler_BlueTooth_request_FIFO_empty			(cmd_handler_BlueTooth_request_FIFO_empty		),
		.cmd_handler_BlueTooth_request_FIFO_surplus			(cmd_handler_BlueTooth_request_FIFO_surplus		),

		// response FIFO signals
		.cmd_handler_BlueTooth_response_FIFO_r_en			(cmd_handler_BlueTooth_response_FIFO_r_en		),
		.cmd_handler_BlueTooth_response_FIFO_data_o			(cmd_handler_BlueTooth_response_FIFO_data_o		),
		.cmd_handler_BlueTooth_response_FIFO_data_o_vld		(cmd_handler_BlueTooth_response_FIFO_data_o_vld	),
		// for debug
		.cmd_handler_BlueTooth_response_FIFO_full			(cmd_handler_BlueTooth_response_FIFO_full		),
		.cmd_handler_BlueTooth_response_FIFO_empty			(cmd_handler_BlueTooth_response_FIFO_empty		),
		.cmd_handler_BlueTooth_response_FIFO_surplus		(cmd_handler_BlueTooth_response_FIFO_surplus	)
	);
	assign BlueTooth_Txd = uart_tx;

endmodule
