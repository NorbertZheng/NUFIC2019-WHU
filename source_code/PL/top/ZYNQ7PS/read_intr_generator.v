module read_intr_generator #(
	parameter			INTR_PERIOD		=	10
) (
	input				clk					,
	input				rst_n				,

	input				read_start_intr		,
	output	reg			read_intr			
);

	localparam			read_intr_generator_IDLE		=	2'b00,
						read_intr_generator_GENERATE	=	2'b01,
						read_intr_generator_END			=	2'b10;

	reg [1:0] read_intr_generator_state;
	reg [4:0] read_intr_generator_cnt;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// state
			read_intr_generator_state <= read_intr_generator_IDLE;
			// inner sigals
			read_intr_generator_cnt <= 5'b0;
			// output
			read_intr <= 1'b0;
			end
		else
			begin
			case (read_intr_generator_state)
				read_intr_generator_IDLE:
					begin
					if (read_start_intr)
						begin
						// state
						read_intr_generator_state <= read_intr_generator_GENERATE;
						// inner signals
						read_intr_generator_cnt <= 5'b0;
						// output
						read_intr <= 1'b1;
						end
					else
						begin
						// state
						read_intr_generator_state <= read_intr_generator_IDLE;
						// inner sigals
						read_intr_generator_cnt <= 5'b0;
						// output
						read_intr <= 1'b0;
						end
					end
				read_intr_generator_GENERATE:
					begin
					if (read_intr_generator_cnt < INTR_PERIOD)		// not enough
						begin
						// inner signals
						read_intr_generator_cnt <= read_intr_generator_cnt + 1'b1;
						// output
						read_intr <= 1'b1;
						end
					else
						begin
						// state
						read_intr_generator_state <= read_intr_generator_END;
						// inner signals
						read_intr_generator_cnt <= 5'b0;
						// output
						read_intr <= 1'b0;
						end
					end
				read_intr_generator_END:
					begin
					if (read_intr_generator_cnt < INTR_PERIOD)		// not enough
						begin
						// inner signals
						read_intr_generator_cnt <= read_intr_generator_cnt + 1'b1;
						// output
						read_intr <= 1'b0;
						end
					else
						begin
						// state
						read_intr_generator_state <= read_intr_generator_IDLE;
						// inner signals
						read_intr_generator_cnt <= 5'b0;
						// output
						read_intr <= 1'b0;
						end
					end
				default:
					begin
					// state
					read_intr_generator_state <= read_intr_generator_IDLE;
					// inner sigals
					read_intr_generator_cnt <= 5'b0;
					// output
					read_intr <= 1'b0;
					end
			endcase
			end
		end

endmodule
