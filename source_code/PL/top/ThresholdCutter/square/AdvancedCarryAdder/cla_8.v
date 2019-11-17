module cla_8(a, b, c_in, g_out, p_out, s);
	/*********************
	 *	8-bit先行进位Add
	 *input:
	 *	a[7:0]	: cla_8 的第一个8-bit操作数
	 *	b[7:0]	: cla_8 的第二个8-bit操作数
	 *	c_in	: cla_8 的来自下一位的进位
	 *output:
	 *	g_out	: cla_8 的进位产生函数
	 *	p_out	: cla_8 的进位传递函数
	 *	s[7:0]	: cla_8 的加法结果
	 *********************/
	input [7:0] a, b;
	input c_in;
	output g_out, p_out;
	output [7:0] s;
	
	wire [1:0] g, p;
	wire c_out;
	cla_4 cla0(
		.a(a[3:0]), 
		.b(b[3:0]), 
		.c_in(c_in), 
		.g_out(g[0]), 
		.p_out(p[0]), 
		.s(s[3:0])
	);
	cla_4 cla1(
		.a(a[7:4]), 
		.b(b[7:4]), 
		.c_in(c_out), 
		.g_out(g[1]), 
		.p_out(p[1]), 
		.s(s[7:4])
	);
	g_p g_p0(
		.g(g), 
		.p(p), 
		.c_in(c_in), 
		.g_out(g_out), 
		.p_out(p_out), 
		.c_out(c_out)
	);
endmodule