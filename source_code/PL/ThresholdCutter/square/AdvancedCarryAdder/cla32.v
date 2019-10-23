module cla32(a, b, ci, s, co);
	/*********************
	 *	32-bit先行进位Add(Complete)
	 *input:
	 *	a[31:0]	: cla32 的第一个32-bit操作数
	 *	b[31:0]	: cla32 的第二个32-bit操作数
	 *	ci		: cla32 的来自下一位的进位
	 *output:
	 *	s[31:0]	: cla32 的加法结果
	 *	co		: cla32 的向上一位的进位
	 *********************/
	input [31:0] a, b;
	input ci;
	output [31:0] s;
	output co;
	
	wire g_out, p_out;
	cla_32 cla(
		.a(a),
		.b(b),
		.c_in(ci), 
		.g_out(g_out), 
		.p_out(p_out), 
		.s(s)
	);
	assign co = g_out | p_out & ci;
endmodule