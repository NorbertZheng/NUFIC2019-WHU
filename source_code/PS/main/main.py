#! /bin/sh python37
import pynq
from pprint import pprint
from DMA_SG.DMA_SG import DMA_SG
from DMA_SG import tools
from pynq.lib import AxiGPIO

data_size = 200 * 8
restart = 1

def flush():
	global restart
	restart = 1

def main():
	global restart

	# download overlay
	overlay = pynq.Overlay("./overlay/top.bit")
	pprint(overlay.ip_dict)

	# init dma_sg controller
	dma_pl2ps_description = overlay.ip_dict['axi_dma_write']
	dma_pl2ps = DMA_SG(dma_pl2ps_description)
	# init AXIGPIO controller
	axi_transmit_intr_description = overlay.ip_dict['axi_transmit_intr']
	axi_transmit_intr = AxiGPIO(axi_transmit_intr_description)
	axi_transmit_intr.setlength(1, channel = 1)
	axi_transmit_intr.setdirection(AxiGPIO.Input, channel = 1)
	pprint(axi_transmit_intr.channel1[0])

	# start reveiver channel
	buffer = dma_pl2ps.recvchannel.transferS2MM(data_size, restart = restart)
	restart = 0
	pprint("Ready to transmit!")

	# end-less loop
	while True:
		# wait AXIGPIO to be 1, enable the transmit
		axi_transmit_intr.channel1[0].wait_for_value(1)
		tools.print_descriptor_attr(dma_pl2ps.recvchannel.descriptor[0])
		tools.print_dma_status(dma_pl2ps)
		tools.print_buffer(buffer)
		buffer = dma_pl2ps.recvchannel.transferS2MM(data_size, restart = restart)
		# wait AXIGPIO to be 0, start next transmit
		axi_transmit_intr.channel1[0].wait_for_value(0)

if __name__ == '__main__':
	main()
