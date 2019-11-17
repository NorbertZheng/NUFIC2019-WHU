module cla_32(a, b, c_in, g_out, p_out, s);
	/*********************
	 *	32-bit先行进位Add
	 *input:
	 *	a[31:0]	: cla_32 的第一个32-bit操作数
	 *	b[31:0]	: cla_32 的第二个32-bit操作数
	 *	c_in	: cla_32 的来自下一位的进位
	 *output:
	 *	g_out	: cla_32 的进位产生函数
	 *	p_out	: cla_32 的进位传递函数
	 *	s[31:0]	: cla_32 的加法结果
	 *********************/
	input [31:0] a, b;
	input c_in;
	output g_out, p_out;
	output [31:0] s;
	
	wire [1:0] g, p;
	wire c_out;
	cla_16 cla0(
		.a(a[15:0]), 
		.b(b[15:0]), 
		.c_in(c_in), 
		.g_out(g[0]), 
		.p_out(p[0]), 
		.s(s[15:0])
	);
	cla_16 cla1(
		.a(a[31:16]), 
		.b(b[31:16]), 
		.c_in(c_out), 
		.g_out(g[1]), 
		.p_out(p[1]), 
		.s(s[31:16])
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