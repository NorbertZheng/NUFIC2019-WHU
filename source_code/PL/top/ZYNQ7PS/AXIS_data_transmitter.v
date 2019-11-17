module AXIS_data_transmitter #(
	parameter		AXIS_DATA_WIDTH		=	256		,
					AXIS_DATA_KEEP		=	32		,
					AXIS_DATA_DEPTH		=	400		
) (
	input									clk									,
	input									rst_n								,

	input									transmit_vld						,
	input		[AXIS_DATA_WIDTH - 1:0]		transmit_data						,
	input									transmit_last						,
	output	reg								transmit_rdy						,

	output	reg	[AXIS_DATA_WIDTH - 1:0]		AXIS_data_transmitter_AXIS_tdata	,
	output		[AXIS_DATA_KEEP - 1:0]		AXIS_data_transmitter_AXIS_tkeep	,
	output	reg								AXIS_data_transmitter_AXIS_tlast	,
	input									AXIS_data_transmitter_AXIS_tready	,
	output	reg								AXIS_data_transmitter_AXIS_tvalid	
);

	localparam			AXIS_data_transmitter_IDLE		=	2'b00,
						AXIS_data_transmitter_TRANSMIT	=	2'b01,
						AXIS_data_transmitter_END		=	2'b10;

	reg [1:0] AXIS_data_transmitter_state;
	reg [1:0] AXIS_data_transmitter_delay;
	reg AXIS_data_transmitter_transmit_last;
	reg [AXIS_DATA_WIDTH - 1:0] AXIS_data_transmitter_transmit_data;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// state
			AXIS_data_transmitter_state <= AXIS_data_transmitter_IDLE;
			// inner signals
			AXIS_data_transmitter_delay <= 2'b0;
			AXIS_data_transmitter_transmit_last <= 1'b0;
			AXIS_data_transmitter_transmit_data <= {AXIS_DATA_WIDTH{1'b0}};
			// output
			transmit_rdy <= 1'b1;
			AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
			AXIS_data_transmitter_AXIS_tlast <= 1'b0;
			AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
			end
		else
			begin
			case (AXIS_data_transmitter_state)
				AXIS_data_transmitter_IDLE:
					begin
					if (transmit_vld)				// start transmit
						begin
						// state
						AXIS_data_transmitter_state <= AXIS_data_transmitter_TRANSMIT;
						// inner signals
						AXIS_data_transmitter_delay <= 2'b0;
						// AXIS_data_transmitter_transmit_last <= transmit_last;
						AXIS_data_transmitter_transmit_last <= 1'b0;
						AXIS_data_transmitter_transmit_data <= transmit_data;
						// output
						transmit_rdy <= 1'b0;		// disable transmit_rdy
						AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
						AXIS_data_transmitter_AXIS_tlast <= 1'b0;
						AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
						end
					else
						begin
						// state
						AXIS_data_transmitter_state <= AXIS_data_transmitter_IDLE;
						// inner signals
						AXIS_data_transmitter_transmit_last <= 1'b0;
						AXIS_data_transmitter_transmit_data <= {AXIS_DATA_WIDTH{1'b0}};
						// output
						transmit_rdy <= 1'b1;
						AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
						AXIS_data_transmitter_AXIS_tlast <= 1'b0;
						AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
						end
					end
				AXIS_data_transmitter_TRANSMIT:
					begin
					if (AXIS_data_transmitter_delay == 2'b11)
						begin
						if (AXIS_data_transmitter_AXIS_tready)
							begin
							// state
							AXIS_data_transmitter_state <= AXIS_data_transmitter_END;
							// inner signals
							// do nothing
							// output
							transmit_rdy <= 1'b0;
							AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
							AXIS_data_transmitter_AXIS_tlast <= 1'b0;
							AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
							end
						else
							begin
							// do nothing
							end
						end
					else if (AXIS_data_transmitter_delay != 2'b0)
						begin
						// inner signals
						AXIS_data_transmitter_delay <= AXIS_data_transmitter_delay + 1'b1;
						// output
						transmit_rdy <= 1'b0;
						AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
						AXIS_data_transmitter_AXIS_tlast <= 1'b0;
						AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
						end
					else
						begin
						// state
						// do nothing
						// inner signals
						AXIS_data_transmitter_delay <= AXIS_data_transmitter_delay + 1'b1;
						// output
						transmit_rdy <= 1'b0;
						AXIS_data_transmitter_AXIS_tdata <= AXIS_data_transmitter_transmit_data;
						AXIS_data_transmitter_AXIS_tvalid <= 1'b1;
						AXIS_data_transmitter_AXIS_tlast <= AXIS_data_transmitter_transmit_last;
						end
					end
				AXIS_data_transmitter_END:
					begin
					// state
					AXIS_data_transmitter_state <= AXIS_data_transmitter_IDLE;
					// inner signals
					AXIS_data_transmitter_delay <= 2'b0;
					AXIS_data_transmitter_transmit_last <= 1'b0;
					AXIS_data_transmitter_transmit_data <= {AXIS_DATA_WIDTH{1'b0}};
					// output
					transmit_rdy <= 1'b1;
					AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
					AXIS_data_transmitter_AXIS_tlast <= 1'b0;
					AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
					end
				default:
					begin
					// state
					AXIS_data_transmitter_state <= AXIS_data_transmitter_IDLE;
					// inner signals
					AXIS_data_transmitter_delay <= 2'b0;
					AXIS_data_transmitter_transmit_last <= 1'b0;
					AXIS_data_transmitter_transmit_data <= {AXIS_DATA_WIDTH{1'b0}};
					// output
					transmit_rdy <= 1'b1;
					AXIS_data_transmitter_AXIS_tdata <= {AXIS_DATA_WIDTH{1'b0}};
					AXIS_data_transmitter_AXIS_tlast <= 1'b0;
					AXIS_data_transmitter_AXIS_tvalid <= 1'b0;
					end
			endcase
			end
		end

	assign AXIS_data_transmitter_AXIS_tkeep = {AXIS_DATA_KEEP{1'b1}};

endmodule
