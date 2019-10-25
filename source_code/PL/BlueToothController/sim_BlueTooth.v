module sim_BlueTooth #(
	parameter		// config
					CLK_FRE								=	50,		// 50MHz
					BAUD_RATE							=	9600,	// 9600Hz (4800, 19200, 38400, 57600, 115200, 38400...)
					TX_DATA_BYTE_WIDTH					=	11,		// 11 bytes to transmit
					RX_DATA_BYTE_WIDTH					=	11		// 11 bytes to receive
	`ifndef			TX_DATA_BIT_WIDTH
	`define			TX_DATA_BIT_WIDTH					(TX_DATA_BYTE_WIDTH << 3)
	`endif
	`ifndef			RX_DATA_BIT_WIDTH
	`define			RX_DATA_BIT_WIDTH					(RX_DATA_BYTE_WIDTH << 3)
	`endif
) (
	input						clk						,
	input						rst_n					,

	// uart signals
	input						uart_rx					,
	output						uart_tx					,		// should connect with BlueTooth_Txd in BlueToothController.v

	// inner data
	input		[`TX_DATA_BIT_WIDTH - 1:0]	tx_data		,		// data
	input									tx_vld		,		// start the transmit process
	output									tx_rdy		,		// transmit process complete
	output		[`RX_DATA_BIT_WIDTH - 1:0]	rx_data		,		// data
	input									rx_ack		,		// data is received by receiver buffer					(RX_WAIT)
	output									rx_rdy				// send signal to receiver buffer that data is ready
);

	// uart_controller
	uart_controller #(
		.CLK_FRE(CLK_FRE),								// 50MHz
		.BAUD_RATE(BAUD_RATE),							// 115200Hz
		.TX_DATA_BYTE_WIDTH(TX_DATA_BYTE_WIDTH),		// 11 bytes to transmit
		.RX_DATA_BYTE_WIDTH(RX_DATA_BYTE_WIDTH)			// 11 bytes to receive
	) m_uart_controller (
		.clk			(clk				),
		.rst_n			(rst_n				),
		.uart_rx		(uart_rx			),
		.uart_tx		(uart_tx			),

		// inner data
		.tx_data		(tx_data			),		// data
		.tx_vld			(tx_vld				),		// start the transmit process
		.tx_rdy			(tx_rdy				),		// transmit process complete
		.rx_data		(rx_data			),		// data
		.rx_ack			(rx_ack				),		// data is received by receiver buffer					(RX_WAIT)
		.rx_rdy			(rx_rdy				)		// send signal to receiver buffer that data is ready
	);

endmodule
