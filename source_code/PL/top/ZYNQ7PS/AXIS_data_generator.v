module AXIS_data_generator #(
	parameter		AXIS_DATA_WIDTH		=	256		,
					AXIS_DATA_KEEP		=	32		,
					AXIS_DATA_DEPTH		=	400		
) (
	input									clk								,
	input									rst_n							,

	output	reg	[AXIS_DATA_WIDTH - 1:0]		AXIS_data_generator_AXIS_tdata	,
	output		[AXIS_DATA_KEEP - 1:0]		AXIS_data_generator_AXIS_tkeep	,
	output	reg								AXIS_data_generator_AXIS_tlast	,
	input									AXIS_data_generator_AXIS_tready	,
	output	reg								AXIS_data_generator_AXIS_tvalid	
);

	reg reset_flag;
	reg AXIS_data_generator_delay;
	reg [9:0] AXIS_data_generator_cnt;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// inner signals
			reset_flag <= 1'b1;
			AXIS_data_generator_delay <= 1'b1;
			AXIS_data_generator_cnt <= 10'b0;
			// output
			AXIS_data_generator_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
			AXIS_data_generator_AXIS_tlast <= 1'b0;
			AXIS_data_generator_AXIS_tvalid <= 1'b0;
			end
		else
			begin
			if (AXIS_data_generator_cnt < AXIS_DATA_DEPTH)
				begin
				if (AXIS_data_generator_delay)
					begin
					if (AXIS_data_generator_AXIS_tready)						// ready to accept data
						begin
						// inner signals
						AXIS_data_generator_delay <= 1'b0;
						AXIS_data_generator_cnt <= AXIS_data_generator_cnt + 1'b1;
						// output
						AXIS_data_generator_AXIS_tdata <= {{(AXIS_DATA_WIDTH - 10){1'b0}}, AXIS_data_generator_cnt};
						AXIS_data_generator_AXIS_tvalid <= 1'b1;
						if (AXIS_data_generator_cnt == AXIS_DATA_DEPTH - 1)		// the last one
							begin
							AXIS_data_generator_AXIS_tlast <= 1'b1;
							end
						else
							begin
							AXIS_data_generator_AXIS_tlast <= 1'b0;
							end
						end
					else
						begin
						// output
						AXIS_data_generator_AXIS_tvalid <= 1'b0;
						AXIS_data_generator_AXIS_tlast <= 1'b0;
						end
					end
				else
					begin
					// inner signals
					AXIS_data_generator_delay <= 1'b1;
					// output
					AXIS_data_generator_AXIS_tvalid <= 1'b0;
					AXIS_data_generator_AXIS_tlast <= 1'b0;
					end
				end
			else
				begin
				if (reset_flag)
					begin
					// output
					AXIS_data_generator_AXIS_tvalid <= 1'b0;
					AXIS_data_generator_AXIS_tlast <= 1'b0;
					end
				else
					begin
					// inner signals
					reset_flag <= 1'b1;
					AXIS_data_generator_delay <= 1'b1;
					AXIS_data_generator_cnt <= 10'b0;
					// output
					AXIS_data_generator_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
					AXIS_data_generator_AXIS_tlast <= 1'b0;
					AXIS_data_generator_AXIS_tvalid <= 1'b0;
					end
				end
			end
		end

	assign AXIS_data_generator_AXIS_tkeep = {AXIS_DATA_KEEP{1'b1}};

endmodule
