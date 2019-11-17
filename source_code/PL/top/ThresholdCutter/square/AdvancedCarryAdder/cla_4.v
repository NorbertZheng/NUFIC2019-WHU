module cla_4(a, b, c_in, g_out, p_out, s);
	/*********************
	 *	4-bit先行进位Add
	 *input:
	 *	a[3:0]	: cla_4 的第一个4-bit操作数
	 *	b[3:0]	: cla_4 的第二个4-bit操作数
	 *	c_in	: cla_4 的来自下一位的进位
	 *output:
	 *	g_out	: cla_4 的进位产生函数
	 *	p_out	: cla_4 的进位传递函数
	 *	s[3:0]	: cla_4 的加法结果
	 *********************/
	input [3:0] a, b;
	input c_in;
	output g_out, p_out;
	output [3:0] s;
	
	wire [1:0] g, p;
	wire c_out;
	cla_2 cla0(
		.a(a[1:0]), 
		.b(b[1:0]), 
		.c_in(c_in), 
		.g_out(g[0]), 
		.p_out(p[0]), 
		.s(s[1:0])
	);
	cla_2 cla1(
		.a(a[3:2]), 
		.b(b[3:2]), 
		.c_in(c_out), 
		.g_out(g[1]), 
		.p_out(p[1]), 
		.s(s[3:2])
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