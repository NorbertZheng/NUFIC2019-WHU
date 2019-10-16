module uart_test #(
	parameter		CLK_FRE				=	50,		// 50MHz
					BAUD_RATE			=	38400,	// 115200Hz
					TX_DATA_BYTE_WIDTH	=	8,		// 8 bytes to transmit
					RX_DATA_BYTE_WIDTH	=	8,		// 8 bytes to receive
					DATA_WIDTH			=	64,		// the bit width of data we stored in the FIFO
					DATA_DEPTH_INDEX	=	3		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
) (
	input									clk			,
	input									rst_n		,
	input									uart_rx		,
	output									uart_tx		
);

	// uart_controller
	wire tx_vld, tx_rdy, rx_ack, rx_rdy, data_i_vld;
	reg rx_rdy_delay;
	wire [(TX_DATA_BYTE_WIDTH  << 3) - 1:0] tx_data;
	wire [(RX_DATA_BYTE_WIDTH  << 3) - 1:0] rx_data;

	// FIFO
	wire FIFO_full, data_o_vld;

	// for FIFO data_i_vld hold just 1 cycle
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			rx_rdy_delay <= 1'b0;
			end
		else
			begin
			rx_rdy_delay <= rx_rdy;
			end
		end
	assign data_i_vld = rx_rdy & ~rx_rdy_delay;		// just 1 cycle

	// for test
	reg r_en, r_en_delay, tx_flag;
	reg [3:0] tx_rdy_buf;
	// TX_WAIT is really a big mess, but I don't prepare to modify it now.
	//					last -> 0 							current -> 1
	wire tx_rdy_pos = ~tx_rdy_buf[3] & tx_rdy_buf[2] & ~tx_rdy_buf[1] & tx_rdy_buf[0];
	reg [DATA_DEPTH_INDEX - 1:0] cnt;
	always@(posedge clk)
		begin
		if (!rst_n)
			begin
			r_en <= 1'b0;
			r_en_delay <= 1'b0;
			tx_flag <= 1'b0;
			cnt <= {DATA_DEPTH_INDEX{1'b0}};
			// for debug
			tx_rdy_buf <= 4'b0;
			end
		else
			begin
			tx_rdy_buf <= {tx_rdy_buf[2:0], tx_rdy};
			r_en_delay <= r_en;
			if (FIFO_full)
				begin
				r_en <= 1'b1;
				cnt <= {DATA_DEPTH_INDEX{1'b0}};
				tx_flag <= 1'b1;
				end
			else
				begin
				if (tx_flag)
					begin
					if (tx_rdy_pos)
						begin
						cnt <= cnt + 1'b1;
						if (cnt == {DATA_DEPTH_INDEX{1'b1}})
							begin
							r_en <= 1'b0;
							tx_flag <= 1'b0;
							end
						else
							begin
							r_en <= 1'b1;
							end
						end
					else
						begin
						// do nothing
						r_en <= 1'b0;
						end
					end
				else
					begin
					// do nothing
					r_en <= 1'b0;
					tx_flag <= 1'b0;
					end
				end
			end
		end

	assign tx_vld = r_en_delay & data_o_vld;

	// uart_controller
	uart_controller #(
		.CLK_FRE(CLK_FRE),
		.BAUD_RATE(BAUD_RATE),
		.TX_DATA_BYTE_WIDTH(TX_DATA_BYTE_WIDTH),
		.RX_DATA_BYTE_WIDTH(RX_DATA_BYTE_WIDTH)
	) m_uart_controller(
		.clk			(clk		),
		.rst_n			(rst_n		),
		.uart_rx		(uart_rx	),
		.uart_tx		(uart_tx	),

		// inner data
		.tx_data		(tx_data	),
		.tx_vld			(tx_vld		),
		.tx_rdy			(tx_rdy		),
		.rx_data		(rx_data	),
		.rx_ack			(rx_ack		),
		.rx_rdy			(rx_rdy		)
	);

	// FIFO
	FIFO #(
		.DATA_WIDTH(DATA_WIDTH),
		.DATA_DEPTH_INDEX(DATA_DEPTH_INDEX)
	) (
		.clk			(clk		),
		.rst_n			(rst_n		),

		.data_i			(rx_data	),
		.data_i_vld		(data_i_vld	),
		.data_i_rdy		(rx_ack		),

		.r_en			(r_en		),
		.data_o			(tx_data	),
		.data_o_vld		(data_o_vld	),

		// for debug
		.FIFO_full		(FIFO_full	)
	);

endmodule
