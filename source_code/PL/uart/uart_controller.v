module uart_controller #(
	parameter		CLK_FRE				=	50,		// 50MHz
					BAUD_RATE			=	115200,	// 115200Hz
					TX_DATA_BYTE_WIDTH	=	18,		// 18 bytes to transmit
					RX_DATA_BYTE_WIDTH	=	8		// 8 bytes to receive
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
	output	reg								tx_rdy		,		// transmit process complete
	output	reg	[`RX_DATA_BIT_WIDTH - 1:0]	rx_data		,		// data
	input									rx_ack		,		// data is received by receiver buffer					(RX_WAIT)
	output	reg								rx_rdy				// send signal to receiver buffer that data is ready
);

	localparam		TX_IDLE		=	2'b00,
					TX_SENDVLD	=	2'b01,
					TX_WAITRDY	=	2'b10,
					TX_WAIT		=	2'b11,
					RX_IDLE		=	2'b00,
					RX_REC		=	2'b01,
					RX_WAIT		=	2'b10;

	// state of tx & rx
	reg [1:0] tstate, rstate;

	// signals of tx & rx
	reg rx_data_rdy, tx_data_vld;
	wire rx_data_vld, tx_data_rdy;
	wire [7:0] rx_data_sub, tx_data_sub;
	reg [7:0] rx_cnt, tx_cnt;								// so we can support 2 ^ 8 = 256 bytes to tx & rx
	reg [`TX_DATA_BIT_WIDTH - 1:0] tx_data_buffer;
	reg [`RX_DATA_BIT_WIDTH - 1:0] rx_data_buffer;

	// tx_data_sub
	assign tx_data_sub = tx_data_buffer[`TX_DATA_BIT_WIDTH - 1:`TX_DATA_BIT_WIDTH - 8];

	// tx 
	reg tx_data_rdy_mask;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// output
			tx_rdy <= 1'b1;					// can accept tx req
			// state
			tstate <= TX_IDLE;
			// inner signals
			tx_data_vld <= 1'b0;
			tx_cnt <= 8'b0;
			tx_data_buffer <= {`TX_DATA_BIT_WIDTH{1'b0}};
			// for debug
			tx_data_rdy_mask <= 1'b0;
			end
		else
			begin
			case (tstate)
				TX_IDLE:
					begin
					if (tx_vld)				// tx_data is valid
						begin
						// output
						tx_rdy <= 1'b0;
						// inner signals
						tstate <= TX_SENDVLD;
						tx_data_vld <= 1'b0;
						tx_cnt <= 8'b0;
						tx_data_buffer <= tx_data;
						// for debug
						tx_data_rdy_mask <= 1'b0;
						end
					else
						begin
						// output
						tx_rdy <= 1'b1;
						// for debug
						tx_data_rdy_mask <= 1'b0;
						end
					end
				TX_SENDVLD:
					begin
					if (tx_cnt < TX_DATA_BYTE_WIDTH)
						begin
						tx_data_vld <= 1'b1;		// only tx_data_vld is valid, tx_data_rdy can be dispelled
						tstate <= TX_WAITRDY;
						// for debug
						tx_data_rdy_mask <= 1'b1;
						end
					else					// all data have been transmitted, set tx_rdy = 1'b1 for one cycle
						begin
						// output
						tx_rdy <= 1'b1;
						// state
						tstate <= TX_IDLE;
						// for debug
						tx_data_rdy_mask <= 1'b0;
						end
					end
				TX_WAITRDY:
					begin
					tx_data_vld <= 1'b0;	// only one cycle valid
					if (tx_data_rdy & ~tx_data_rdy_mask)		// if this sub transmission is complete 
						begin
						// state
						tstate <= TX_SENDVLD;
						// inner signals
						tx_cnt <= tx_cnt + 1'b1;
						tx_data_buffer <= {tx_data_buffer[`TX_DATA_BIT_WIDTH - 9:0], 8'b0};
						// for debug
						tx_data_rdy_mask <= 1'b1;
						end
					else
						begin
						// for debug
						tx_data_rdy_mask <= 1'b0;
						end
					end
				/*TX_WAIT:					// for one cycle rdy signal
					begin
					tx_rdy <= 1'b1;			// tx_rdy <= 1'b0;
					tstate <= TX_IDLE;
					// for debug
					tx_data_rdy_mask <= 1'b0;
					end*/
				default:					// same with rst_n, for unpredict situation
					begin
					// output
					tx_rdy <= 1'b1;			// can accept tx req
					// state
					tstate <= TX_IDLE;
					// inner signals
					tx_data_vld <= 1'b0;
					tx_cnt <= 8'b0;
					tx_data_buffer <= {`TX_DATA_BIT_WIDTH{1'b0}};
					// for debug
					tx_data_rdy_mask <= 1'b0;
					end
			endcase
			end
		end

	// rx
	reg rx_data_vld_mask;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// output
			rx_data <= {`RX_DATA_BIT_WIDTH{1'b0}};
			rx_rdy <= 1'b0;					// init data is invalid
			// state
			rstate <= RX_IDLE;
			// inner signals
			rx_data_rdy <= 1'b0;			// receive data ACK
			rx_cnt <= 8'b0;
			// for debug
			rx_data_vld_mask <= 1'b0;
			end
		else
			begin
			case (rstate)
				RX_IDLE:
					begin
					if (rx_data_vld & ~rx_data_vld_mask)		// rx_data_vld just hold for 1 cycle
						begin
						// output
						rx_data <= {rx_data[`RX_DATA_BIT_WIDTH - 9:0], rx_data_sub};
						rx_rdy <= 1'b0;		// not ready totally
						// state
						rstate <= RX_REC;
						// inner signals
						rx_data_rdy <= 1'b1;// continue to receive data, for just receive the first byte of the RX_DATA_BYTE_WIDTH
						rx_cnt <= rx_cnt + 1'b1;
						// for debug
						rx_data_vld_mask <= 1'b1;
						end
					else
						begin
						rx_rdy <= 1'b0;		// no data come
						// for debug
						rx_data_vld_mask <= 1'b0;
						end
					end
				RX_REC:
					begin
					if (rx_cnt < RX_DATA_BYTE_WIDTH)
						begin
						if (rx_data_vld & ~rx_data_vld_mask)	// rx_data_vld just hold for 1 cycle
							begin
							// output
							rx_data <= {rx_data[`RX_DATA_BIT_WIDTH - 9:0], rx_data_sub};
							// inner signals
							rx_data_rdy <= 1'b1;		// continue to receive data, for just receive the first byte of the RX_DATA_BYTE_WIDTH
							rx_cnt <= rx_cnt + 1'b1;
							// for debug
							rx_data_vld_mask <= 1'b1;
							end
						else
							begin
							// inner signals
							rx_data_rdy <= 1'b0;		// just 1 cycle rdy signal, for rx state change
							// for debug
							rx_data_vld_mask <= 1'b0;
							end
						end
					else					// rx complete
						begin
						rx_data_rdy <= 1'b0;			// just 1 cycle rdy signal, for rx state change
						rx_rdy <= 1'b1;					// generate multi-cycle rx_rdy signal, wait until receiver buffer to accept it.
						rstate <= RX_WAIT;
						// for debug
						rx_data_vld_mask <= 1'b0;
						end
					end
				RX_WAIT:
					begin
					if (rx_ack)
						begin
						// output
						rx_data <= {`RX_DATA_BIT_WIDTH{1'b0}};
						rx_rdy <= 1'b0;
						// state
						rstate <= RX_IDLE;
						// inner signals
						rx_data_rdy <= 1'b0;			// receive data ACK
						rx_cnt <= 8'b0;
						end
					else
						begin
						// do nothing
						end
					end
				default:
					begin
					// output
					rx_data <= {`RX_DATA_BIT_WIDTH{1'b0}};
					rx_rdy <= 1'b0;
					// state
					rstate <= RX_IDLE;
					// inner signals
					rx_data_rdy <= 1'b0;			// receive data ACK
					rx_cnt <= 8'b0;
					end
			endcase
			end
		end

	// uart_rx
	uart_rx #(
		.CLK_FRE(CLK_FRE),
		.BAUD_RATE(BAUD_RATE)
	) m_uart_rx (
		.clk						(clk			),
		.rst_n						(rst_n			),
		.rx_data					(rx_data_sub	),		// wire [7:0]
		.rx_rdy						(rx_data_vld	),
		.rx_ack						(rx_data_rdy	),
		.uart_rx					(uart_rx		)
	);

	// uart_tx
	uart_tx # (
		.CLK_FRE(CLK_FRE),
		.BAUD_RATE(BAUD_RATE)
	) m_uart_tx (
		.clk						(clk			),
		.rst_n						(rst_n			),
		.tx_data					(tx_data_sub	),		// wire [7:0]
		.tx_vld						(tx_data_vld	),
		.tx_rdy						(tx_data_rdy	),
		.uart_tx					(uart_tx		)
	);

endmodule
