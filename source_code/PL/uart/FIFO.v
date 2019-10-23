module FIFO #(
	parameter		DATA_WIDTH		=	64	,		// the bit width of data we stored in the FIFO
					DATA_DEPTH_INDEX=	3			// the index_width of data unit(reg [DATA_WIDTH - 1:0])
	`define			DATA_DEPTH			(1 << DATA_DEPTH_INDEX)
) (
	input								clk			,
	input								rst_n		,

	input		[DATA_WIDTH - 1:0]		data_i		,
	input								data_i_vld	,
	output	reg							data_i_rdy	,

	input								r_en		,
	output	reg	[DATA_WIDTH - 1:0]		data_o		,
	output	reg							data_o_vld	,

	// for debug
	output								FIFO_full	,
	output								FIFO_empty	,
	output		[DATA_DEPTH_INDEX - 1:0]FIFO_surplus
);

	// inner buffer
	reg [DATA_WIDTH - 1:0] FIFO[`DATA_DEPTH - 1:0];
	(*mark_debug = "true"*)wire [DATA_WIDTH - 1:0] debug_FIFO[`DATA_DEPTH - 1:0];
	genvar i;
	generate
	for (i = 0; i < `DATA_DEPTH; i = i + 1)
		begin
		assign debug_FIFO[i] = FIFO[i];
		end
	endgenerate
	reg [DATA_DEPTH_INDEX - 1:0] head, tail;		// head always point to the next read data

	// head for read
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// inner signals
			head <= {DATA_DEPTH_INDEX{1'b0}};
			data_o <= {DATA_WIDTH{1'b0}};
			data_o_vld <= 1'b0;
			end
		else
			begin
			if (r_en)				// prepare to read
				begin
				if (FIFO_empty)		// FIFO is empty
					begin
					data_o <= {DATA_WIDTH{1'b0}};
					data_o_vld <= 1'b0;
					end
				else				// means that FIFO is not empty
					begin
					head <= head + 1'b1;
					data_o <= FIFO[head];
					data_o_vld <= 1'b1;
					end
				end
			else
				begin
				data_o <= {DATA_WIDTH{1'b0}};
				data_o_vld <= 1'b0;
				end
			end
		end

	// tail for write
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// do nothing, avoid conflicting with the former block
			tail <= {DATA_DEPTH_INDEX{1'b0}};
			data_i_rdy <= 1'b0;
			end
		else
			begin
			if (data_i_vld)
				begin
				if (FIFO_full)				// FIFO is alreay full
					begin
					data_i_rdy <= 1'b0;
					end
				else						// not full
					begin
					FIFO[tail] <= data_i;
					tail <= tail + 1'b1;
					data_i_rdy <= 1'b1;
					end
				end
			else
				begin
				data_i_rdy <= 1'b0;			// cannot write
				end
			end
		end

	// for debug
	assign FIFO_full = (tail + 1'b1 == head);
	assign FIFO_empty = (tail == head);
	assign FIFO_surplus = head - tail - 1'b1;

endmodule
