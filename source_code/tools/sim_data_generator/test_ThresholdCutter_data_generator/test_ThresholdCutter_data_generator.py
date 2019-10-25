wr_str_b51 = "\t\ttx_vld = 1'b1;\n" + \
"\t\ttx_data = 88'h55_50_" + \
"00_00_00_00_00_00_" + \
"00_00_00;\n" + \
"\t\t# 100;\n" + \
"\t\ttx_vld = 1'b0;\n" + \
"\t\t# 3999900;\t\t// 400 - period\n"

wr_str_a51 = "\t\ttx_vld = 1'b1;\n" + \
"\t\ttx_data = 88'h55_52_" + \
"00_00_00_00_00_00_" + \
"00_00_00;\n" + \
"\t\t# 100;\n" + \
"\t\ttx_vld = 1'b0;\n" + \
"\t\t# 39900;\t\t// 400 - period\n" + \
"\t\ttx_vld = 1'b1;\n" + \
"\t\ttx_data = 88'h55_53_" + \
"00_00_00_00_00_00_" + \
"00_00_00;\n" + \
"\t\t# 100;\n" + \
"\t\ttx_vld = 1'b0;\n" + \
"\t\t# 3999900;\t\t// 400 - period\n"

def generate_test_ThresholdCutter_data(zero_flag = 0):
	i = 0;
	with open("test_ThresholdCutter_data.dat", "a+") as f:
		while i <= 0xff:
			wr_str = "\t\ttx_vld = 1'b1;\n" + \
			"\t\ttx_data = 88'h55_51_"
			if not zero_flag:
				if i >= 16:
					wr_str += hex(i)[2:] + "_20_" + hex(i)[2:] + "_20_" + hex(i)[2:] + "_20_"
				else:
					wr_str += "0" + hex(i)[2] + "_20_" + "0" + hex(i)[2] + "_20_" + "0" + hex(i)[2] + "_20_"
			else:
				wr_str += "00_00_00_00_00_00_"
			i += 1
			wr_str += "00_00_00;\n" + \
			"\t\t# 100;\n" + \
			"\t\ttx_vld = 1'b0;\n" + \
			"\t\t# 3999900;\t\t// 400 - period\n"
			f.write(wr_str_b51 + wr_str + wr_str_a51)

def main():
	generate_test_ThresholdCutter_data(zero_flag = int(input("zero_flag: "), 10))

if __name__ == "__main__":
	main()
