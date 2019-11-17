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

	/*// uart_rx signals
	wire rx_clk_bps, rx_bps_start;

	// uart_tx signals
	wire tx_clk_bps, tx_bps_start;

	// uart_rx_speed_setting
	speed_setting #(
		.CLK_FRE(CLK_FRE),		// 50MHz(from PLL)
		.BAUD_RATE(BAUD_RATE)
	) m_uart_rx_speed_setting (
		.clk						(clk			),
		.rst_n						(rst_n			),

		.bps_start					(rx_bps_start	),
		.clk_bps					(rx_clk_bps		)
	);

	// uart_tx_speed_setting
	speed_setting #(
		.CLK_FRE(CLK_FRE),		// 50MHz(from PLL)
		.BAUD_RATE(BAUD_RATE)
	) m_uart_tx_speed_setting (
		.clk						(clk			),
		.rst_n						(rst_n			),

		.bps_start					(tx_bps_start	),
		.clk_bps					(tx_clk_bps		)
	);*/

	// uart_rx
	uart_rx #(
		.CLK_FRE(CLK_FRE),		// 50MHz(from PLL)
		.BAUD_RATE(BAUD_RATE)
	) m_uart_rx (
		.clk						(clk			),
		.rst_n						(rst_n			),

		// speed_setting signals
		//.clk_bps					(rx_clk_bps		),
		//.bps_start					(rx_bps_start	),

		// rx signals
		.uart_rx					(uart_rx		),
		.rx_ack						(rx_ack			),
		.rx_data					(rx_data		),
		.rx_rdy						(rx_rdy			)
	);

	// uart_tx
	uart_tx #(
		.CLK_FRE(CLK_FRE),		// 50MHz(from PLL)
		.BAUD_RATE(BAUD_RATE)
	) m_uart_tx (
		.clk						(clk			),
		.rst_n						(rst_n			),

		// speed_setting signals
		//.clk_bps					(tx_clk_bps		),
		//.bps_start					(tx_bps_start	),

		// tx signals
		.tx_data					(tx_data		),
		.tx_vld						(tx_vld			),
		.tx_rdy						(tx_rdy			),
		.uart_tx					(uart_tx		)
	);

endmodule
