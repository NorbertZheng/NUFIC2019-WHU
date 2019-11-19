import numpy as np
from pynq import Xlnk

__author__ = 'Fassial'
__copyright__ = 'Copyright 2019, WHU'
__email__ = 'fassial19991217@gmail.com'

data_size = 200 * 8

def split_by_n(str, n = 4):
	str_list = [((str[n * i:(n * i + n)] + "_") if (i != (len(str) // n) - 1) else str[n * i:(n * i + n)]) for i in range(len(str) // 4)]
	new_str = ""
	for substr in str_list:
		new_str += substr
	return new_str

def print_dma_status(DMA_SG):
	dma_sg_mmio = DMA_SG.get_mmio()

	print("\n==== From FIFO to Memory ====")
	print("MM2S DMA Control register:              0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x00), '0b').rjust(32,'0')))
	print("MM2S DMA Status register:               0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x04), '0b').rjust(32,'0')))
	print("MM2S Current Descriptor Pointer. Lower: 0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x08), '0b').rjust(32,'0')))
	print("MM2S Current Descriptor Pointer. Upper: 0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x0c), '0b').rjust(32,'0')))
	print("MM2S Tail Descriptor Pointer. Lower:    0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x10), '0b').rjust(32,'0')))
	print("MM2S Tail Descriptor Pointer. Upper:    0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x14), '0b').rjust(32,'0')))
	print("Scatter/Gather User and Cache:          0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x2c), '0b').rjust(32,'0')))
	print("S2MM DMA Control register:              0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x30), '0b').rjust(32,'0')))
	print("S2MM DMA Status register:               0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x34), '0b').rjust(32,'0')))
	print("S2MM Current Descriptor Pointer. Lower: 0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x38), '0b').rjust(32,'0')))
	print("S2MM Current Descriptor Pointer. Upper: 0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x3c), '0b').rjust(32,'0')))
	print("S2MM Tail Descriptor Pointer. Lower:    0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x40), '0b').rjust(32,'0')))
	print("S2MM Tail Descriptor Pointer. Upper:    0b " + 
		  split_by_n(format(dma_sg_mmio.read(0x44), '0b').rjust(32,'0')))

def print_descriptor_attr(descriptor):
	print("Next Descriptor Pointer Lower:   0b " + 
		  split_by_n(format(descriptor[0], '0b').rjust(32,'0')))
	print("Next Descriptor Pointer Upper:   0b " + 
		  split_by_n(format(descriptor[1], '0b').rjust(32,'0')))
	print("Buffer Address Lower:            0b " + 
		  split_by_n(format(descriptor[2], '0b').rjust(32,'0')))
	print("Buffer Address Upper:            0b " + 
		  split_by_n(format(descriptor[3], '0b').rjust(32,'0')))
	print("Reversed:                        0b " + 
		  split_by_n(format(descriptor[4], '0b').rjust(32,'0')))
	print("Reversed:                        0b " + 
		  split_by_n(format(descriptor[5], '0b').rjust(32,'0')))
	print("Control:                         0b " + 
		  split_by_n(format(descriptor[6], '0b').rjust(32,'0')))
	print("Status:                          0b " + 
		  split_by_n(format(descriptor[7], '0b').rjust(32,'0')))
	print("APP0:                            0b " + 
		  split_by_n(format(descriptor[8], '0b').rjust(32,'0')))
	print("APP1:                            0b " + 
		  split_by_n(format(descriptor[9], '0b').rjust(32,'0')))
	print("APP2:                            0b " + 
		  split_by_n(format(descriptor[10], '0b').rjust(32,'0')))
	print("APP3:                            0b " + 
		  split_by_n(format(descriptor[11], '0b').rjust(32,'0')))
	print("APP4:                            0b " + 
		  split_by_n(format(descriptor[12], '0b').rjust(32,'0')))

def print_buffer(buffer, data_size = data_size):
	for i in range(data_size):
		print('0x' + format(buffer[0][i], '02x').rjust(8,'0'), end = "")
		if i % 8 == 7:
			print("")
		else:
			print(",", end = "")

def alloc_descriptor(Control, data_size, NDPL = 0x0, NDPU = 0x0, Status = 0x0, APP0 = 0x0, APP1 = 0x0, APP2 = 0x0, APP3 = 0x0, APP4 = 0x0):
	mmu = Xlnk()
	descriptor = mmu.cma_array([13, ])
	descriptor[0] = NDPL
	descriptor[1] = NDPU
	buffer = mmu.cma_array([1, data_size])
	descriptor[2] = buffer.physical_address & 0xffffffff
	descriptor[3] = (buffer.physical_address >> 32) & 0xffffffff
	# Reversed
	descriptor[4] = 0x0
	descriptor[5] = 0x0
	descriptor[6] = Control
	descriptor[7] = Status
	descriptor[8] = APP0
	descriptor[9] = APP1
	descriptor[10] = APP2
	descriptor[11] = APP3
	descriptor[12] = APP4
	return descriptor, buffer

def alloc_single_loop_descriptor(Control, data_size, Status = 0x0, APP0 = 0x0, APP1 = 0x0, APP2 = 0x0, APP3 = 0x0, APP4 = 0x0):
	descriptor, buffer = alloc_descriptor(Control, data_size, NDPL = 0x0, NDPU = 0x0, Status = Status, APP0 = APP0, APP1 = APP1, APP2 = APP2, APP3 = APP3, APP4 = APP4)
	descriptor[0] = descriptor.physical_address & 0xffffffff
	descriptor[1] = (descriptor.physical_address >> 32) & 0xffffffff
	return descriptor, buffer
