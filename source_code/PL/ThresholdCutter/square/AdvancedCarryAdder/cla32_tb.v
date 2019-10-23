`timescale 1us/1ps
module cla32_tb();
	reg [31:0] a, b;
	reg ci;
	wire [31:0] s;
	wire co;
	
	cla32 m_cla32(
		.a(a),
		.b(b),
		.ci(ci),
		.s(s),
		.co(co)
	);
	
	initial
		begin
		a = 32'b0;
		b = 32'b0;
		ci = 1'b0;
		# 100;
		a = 32'h77777777;
		b = 32'hffffffff;
		# 50;
		ci = 1'b1;
		# 50;
		a = 32'haaaaaaaa;
		b = 32'h55555555;
		ci = 1'b0;
		# 50;
		ci = 1'b1;
		# 50;
		a = 32'h00000000;
		b = 32'h00000000;
		ci = 1'b0;
		# 50;
		ci = 1'b1;
		# 50;
		a = 32'hcccccccc;
		b = 32'hcccccccc;
		ci = 1'b0;
		# 50;
		ci = 1'b1;
		# 50;
		end
endmodule