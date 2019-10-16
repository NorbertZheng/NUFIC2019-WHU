module uart_rx #(

) (
	input				clk			,
	input				rst_n		,

	// speed_setting signals
	input				clk_bps		,
	output				bps_start	,

	// rx signals
	input				uart_rx		,
	input				rx_ack		,
	output		[7:0]	rx_data		,
	output	reg			rx_rdy		
);

	// recognize the start of rx
	reg uart_rx0, uart_rx1, uart_rx2, uart_rx3;
	wire neg_uart_rx;
	always@(posedge clk or negedge rst_n)
		begin
		if(!rst_n)
			begin
			uart_rx0 <= 1'b0;
			uart_rx1 <= 1'b0;
			uart_rx2 <= 1'b0;
			uart_rx3 <= 1'b0;
			end
		else
			begin
			uart_rx0 <= uart_rx;
			uart_rx1 <= uart_rx0;
			uart_rx2 <= uart_rx1;
			uart_rx3 <= uart_rx2;
			end
		end
	assign neg_uart_rx = uart_rx3 & uart_rx2 & ~uart_rx1 & ~uart_rx0;

	// generate rx_int
	reg bps_start_r, rx_int;
	reg [3:0] num;
	always@(posedge clk or negedge rst_n)
		begin
		if(!rst_n)
			begin
			// inner signals
			bps_start_r <= 1'bz;
			rx_int <= 1'b0;
			// output
			rx_rdy <= 1'b0;
			end
		else if (neg_uart_rx)
			begin
			if (rx_rdy)				// the last rx_data is still not be taken away
				begin
				if (rx_ack)
					begin
					// inner signals
					bps_start_r <= 1'b0;
					rx_int <= 1'b0;
					// output
					rx_rdy <= 1'b0;
					end
				else
					begin
					// do nothing
					end
				end
			else
				begin
				// inner signals
				bps_start_r <= 1'b1;
				rx_int <= 1'b1;
				// output
				rx_rdy <= 1'b0;
				end
			end
		else if (num == 4'd9)
			begin
			// inner signals
			bps_start_r <= 1'b0;
			rx_int <= 1'b0;
			// output
			rx_rdy <= 1'b1;
			end
		else
			begin
			if (rx_ack)
				begin
				// inner signals
				bps_start_r <= 1'b0;
				rx_int <= 1'b0;
				// output
				rx_rdy <= 1'b0;
				end
			else
				begin
				// do nothing
				end
			end
		end

	// rx
	reg[7:0] rx_data_r;
	reg[7:0] rx_temp_data;
	always@(posedge clk or negedge rst_n)
		begin
		if(!rst_n)
			begin
			rx_temp_data <= 8'd0;
			num <= 4'd0;
			rx_data_r <= 8'd0;
			end
		else if(rx_int)
			begin
			if(clk_bps)
				begin
				num <= num + 1'b1;
				case(num)
					4'd1:
						begin
						rx_temp_data[0] <= uart_rx;
						end
					4'd2:
						begin
						rx_temp_data[1] <= uart_rx;
						end
					4'd3:
						begin
						rx_temp_data[2] <= uart_rx;
						end
					4'd4:
						begin
						rx_temp_data[3] <= uart_rx;
						end
					4'd5:
						begin
						rx_temp_data[4] <= uart_rx;
						end
					4'd6:
						begin
						rx_temp_data[5] <= uart_rx;
						end
					4'd7:
						begin
						rx_temp_data[6] <= uart_rx;
						end
					4'd8:
						begin
						rx_temp_data[7] <= uart_rx;
						end
					default:;
				endcase
				end
			else if(num == 4'd9)
				begin
				num <= 4'd0;
				rx_data_r <= rx_temp_data;
				end
			end
		end

	assign bps_start = bps_start_r;
	assign rx_data = rx_data_r;

endmodule
