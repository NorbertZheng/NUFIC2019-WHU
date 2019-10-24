def generate_test_ThresholdCutterWindow_data(zero_flag = 0):
	i = 0;
	with open("test_ThresholdCutterWindow_data.dat", "a+") as f:
		while i <= 0xff:
			wr_str = "\t\tdata_wen = 1'b1;\n\t\t" + \
			"//\t\t\t   |<--\t\t\t\t--->| |<--Ax---Ay----Az--T--->||<--Wx--Wy---Wz---T-->||<-Roll-Pit--Yaw--T-->|\n" + \
			"\t\tdata_i = 256'h00_00_00_00_00_00_00_00_"
			if not zero_flag:
				if i >= 16:
					wr_str += hex(i)[2:] + "_20_" + hex(i)[2:] + "_20_" + hex(i)[2:] + "_20_"
				else:
					wr_str += "0" + hex(i)[2] + "_20_" + "0" + hex(i)[2] + "_20_" + "0" + hex(i)[2] + "_20_"
			else:
				wr_str += "00_00_00_00_00_00_"
			i += 1
			wr_str += "00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00;\n" + \
			"\t\t# 100;\n" + \
			"\t\tdata_wen = 1'b0;\n" + \
			"\t\t# 39900;\t\t// 400 - period\n"
			f.write(wr_str)

def main():
	generate_test_ThresholdCutterWindow_data(zero_flag = 1)

if __name__ == "__main__":
	main()