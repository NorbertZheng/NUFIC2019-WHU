module uart_controller8bit #(
	parameter		CLK_FRE				=	50,		// 50MHz
					BAUD_RATE			=	115200,	// 115200Hz
	localparam		TX_DATA_BYTE_WIDTH	=	1,		// 1 bytes to transmit
					RX_DATA_BYTE_WIDTH	=	1		// 1 bytes to receive
	`define			TX_DATA_BIT_WIDTH	(TX_DATA_BYTE_WIDTH << 3)
	`define			RX_DATA_BIT_WIDTH	(RX_DATA_BYTE_WIDTH << 3)
) (
	input									clk			,
	input									rst_n		,
	input									uart_rx		,
	output									uart_tx		,

	// inner data
	input		[`TX_DATA_BIT_WIDTH - 1:0]	tx_data		,		// data
	input									tx_vld		,		// start the transmit process
	output									tx_rdy		,		// transmit process complete
	output		[`RX_DATA_BIT_WIDTH - 1:0]	rx_data		,		// data
	input									rx_ack		,		// data is received by receiver buffer					(RX_WAIT)
	output									rx_rdy				// send signal to receiver buffer that data is ready
);

	// uart_rx
	uart_rx #(
		.CLK_FRE(CLK_FRE),
		.BAUD_RATE(BAUD_RATE)
	) m_uart_rx (
		.clk						(clk			),
		.rst_n						(rst_n			),
		.rx_data					(rx_data		),		// wire [7:0]
		.rx_data_valid				(rx_rdy			),
		.rx_data_ready				(rx_ack			),
		.rx_pin						(uart_rx		)
	);

	// uart_tx
	uart_tx # (
		.CLK_FRE(CLK_FRE),
		.BAUD_RATE(BAUD_RATE)
	) m_uart_tx (
		.clk						(clk			),
		.rst_n						(rst_n			),
		.tx_data					(tx_data		),		// wire [7:0]
		.tx_data_valid				(tx_vld			),
		.tx_data_ready				(tx_rdy			),
		.tx_pin						(uart_tx		)
	);

endmodule
