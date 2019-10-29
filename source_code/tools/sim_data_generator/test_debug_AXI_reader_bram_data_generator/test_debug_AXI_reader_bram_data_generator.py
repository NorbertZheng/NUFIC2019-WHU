head_str = "memory_initialization_radix = 16;\nmemory_initialization_vector =\n"
dat_file = "test_debug_AXI_reader_bram_data.dat"

def test_debug_AXI_reader_bram_data_generator():
	str = ""
	for i in range(512):
		# print(hex(i)[2:].zfill(256 // 8))
		# print(len(hex(i)[2:].zfill(256 // 8)))
		str += hex(i)[2:].zfill(256 // 8) + "\n"
	with open(dat_file, "a+") as f:
		f.write(head_str + str)

def main():
	test_debug_AXI_reader_bram_data_generator()

if __name__ == '__main__':
	main()
