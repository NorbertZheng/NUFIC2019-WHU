module speed_setting #(
	parameter		CLK_FRE		=	50,		// 50MHz(from PLL)
					BAUD_RATE	=	9600	// 9600Hz
	`define			CLK_PERIORD		(1000 / CLK_FRE)
	`define			BPS_SET			(BAUD_RATE / 100)
	`define			BPS_PARA		(10_000_000 / `CLK_PERIORD / `BPS_SET)
	`define			BPS_PARA_2		(`BPS_PARA / 2)
) (
	input		clk			,
	input		rst_n		,
	input		bps_start	,
	output		clk_bps		
);

	reg clk_bps_r;
	reg[2:0] uart_ctrl;
	reg[12:0] cnt;

	always@(posedge clk or negedge rst_n)
		begin
		if(!rst_n)
			begin
			cnt <= 13'd0;
			end
		else if((cnt == `BPS_PARA) || !bps_start)
			begin
			cnt <= 13'd0;
			end
		else
			begin
			cnt <= cnt + 1'b1;
			end
		end

	always@(posedge clk or negedge rst_n)
		begin
		if(!rst_n)
			begin
			clk_bps_r <= 1'b0;
			end
		else if(cnt == `BPS_PARA_2)
			begin
			clk_bps_r <= 1'b1;
			end
		else
			begin
			clk_bps_r <= 1'b0;
			end
		end

	assign clk_bps = clk_bps_r;

endmodule
