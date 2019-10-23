module uart_tx #(

) (
	input				clk			,
	input				rst_n		,

	// speed_setting signals
	input				clk_bps		,
	output				bps_start	,

	// tx signals
	input		[7:0]	tx_data		,
	input				tx_vld		,
	output	reg			tx_rdy		,
	output				uart_tx		
);

	// tx_en generate
	reg bps_start_r;
	reg tx_en;
	reg [3:0] num;
	reg [7:0] tx_data_reg;
	// for debug
	reg [31:0] tx_data_reg_buf;
	(* mark_debug = "true" *)wire [31:0] debug_tx_data_reg_buf = tx_data_reg_buf;
	always@(posedge clk)
		begin
		if(!rst_n)
			begin
			// inner signals
			bps_start_r <= 1'bz;
			tx_en <= 1'b0;
			tx_data_reg <= 8'd0;
			// output
			tx_rdy <= 1'b1;
			// for debug
			tx_data_reg_buf <= 32'b0;
			end
		else if (tx_vld)
			begin
			// inner signals
			bps_start_r <= 1'b1;
			tx_data_reg <= tx_data;
			tx_en <= 1'b1;
			// output
			tx_rdy <= 1'b0;
			// for debug
			tx_data_reg_buf <= {tx_data_reg_buf[23:0], tx_data};
			end
		else if (num == 4'd10)
			begin
			// inner signals
			bps_start_r <= 1'b0;
			tx_en <= 1'b0;
			// output
			tx_rdy <= 1'b1;
			end
		end

	// transmission
	reg uart_tx_r;
	always@(posedge clk)
		begin
		if(!rst_n)
			begin
			num <= 4'd0;
			uart_tx_r <= 1'b1;
			end
		else if(tx_en)
			begin
			if(clk_bps)
				begin
				num <= num + 1'b1;
				case(num)
					4'd0:
						begin
						uart_tx_r <= 1'b0;
						end
					4'd1:
						begin
						uart_tx_r <= tx_data_reg[0];
						end
					4'd2:
						begin
						uart_tx_r <= tx_data_reg[1];
						end
					4'd3:
						begin
						uart_tx_r <= tx_data_reg[2];
						end
					4'd4:
						begin
						uart_tx_r <= tx_data_reg[3];
						end
					4'd5:
						begin
						uart_tx_r <= tx_data_reg[4];
						end
					4'd6:
						begin
						uart_tx_r <= tx_data_reg[5];
						end
					4'd7:
						begin
						uart_tx_r <= tx_data_reg[6];
						end
					4'd8:
						begin
						uart_tx_r <= tx_data_reg[7];
						end
					4'd9:
						begin
						uart_tx_r <= 1'b1;
						end
					default:
						begin
						uart_tx_r <= 1'b1;
						end
				endcase
				end
			else if(num == 4'd10)
				begin
				num <= 4'd0;
				end
			end
		end

	assign uart_tx = uart_tx_r;
	assign bps_start = bps_start_r;

endmodule
