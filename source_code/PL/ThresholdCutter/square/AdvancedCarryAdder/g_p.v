module g_p(g, p, c_in, g_out, p_out, c_out);
	/*********************
	 *		GP生成器
	 *input:
	 *	g[1:0] 	: 来自上一层2个临近 add 的g
	 *	p[1:0] 	: 来自上一层2个临近 add 的p
	 *	c_in	: 来自下一层 g_p 的 c 进位
	 *output:
	 *	g_out	: 送往下一层 g_p 的 g
	 *	p_out	: 送往下一层 g_p 的 p
	 *	c_out	: 送往上一层 g_p / add 的 c 进位
	 *********************/
	input [1:0] g, p;
	input c_in;
	output g_out, p_out, c_out;
	
	assign g_out = g[1] | p[1] & g[0];
	assign p_out = p[1] & p[0];
	assign c_out = g[0] | p[0] & c_in;
endmodule