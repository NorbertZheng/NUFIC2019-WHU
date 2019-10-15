module BlueToothInitializer #(

) (
	input			clk,
	input			rst_n,

	output	reg		BlueToothInitializer_init_flag,
	output	reg		BlueToothInitializer_Key
);

	reg [5:0] BlueToothInitializer_cnt;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			BlueToothInitializer_init_flag <= 1'b0;
			BlueToothInitializer_cnt <= 6'b0;
			BlueToothInitializer_Key <= 1'b0;
			end
		else
			begin
			BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
			if (BlueToothInitializer_init_flag == 1'b0 && BlueToothInitializer_cnt == 6'b11_1111)
				begin
				BlueToothInitializer_init_flag <= 1'b1;
				BlueToothInitializer_Key <= 1'b1;
				end
			else
				begin
				// do nothing
				end
			end
		end

endmodule
