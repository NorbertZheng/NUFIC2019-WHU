module add(a, b, c, g, p ,s);
	/*********************
	 *input:
	 *	a: add 的第一个操作数
	 *	b: add 的第二个操作数
	 *	c: add 的来自下一位的进位
	 *output:
	 *	g: add 的进位产生函数
	 *	p: add 的进位传递函数
	 *	s: add 的加法结果
	 *********************/
	input a, b, c;
	output g, p, s;
	
	assign s = a ^ b ^ c;
	assign g = a & b;
	assign p = a | b;
endmodule