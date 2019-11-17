module cla_2(a, b, c_in, g_out, p_out, s);
	/*********************
	 *	2-bit先行进位Add
	 *input:
	 *	a[1:0]	: cla_2 的第一个2-bit操作数
	 *	b[1:0]	: cla_2 的第二个2-bit操作数
	 *	c_in	: cla_2 的来自下一位的进位
	 *output:
	 *	g_out	: cla_2 的进位产生函数
	 *	p_out	: cla_2 的进位传递函数
	 *	s[1:0]	: cla_2 的加法结果
	 *********************/
	input [1:0] a, b;
	input c_in;
	output g_out, p_out;
	output [1:0] s;
	
	wire [1:0] g, p;
	wire c_out;
	add add0(
		.a(a[0]), 
		.b(b[0]), 
		.c(c_in), 
		.g(g[0]), 
		.p(p[0]),
		.s(s[0])
	);
	add add1(
		.a(a[1]), 
		.b(b[1]), 
		.c(c_out), 
		.g(g[1]), 
		.p(p[1]),
		.s(s[1])
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