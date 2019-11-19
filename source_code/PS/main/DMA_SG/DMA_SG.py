import warnings
import numpy as np
from pynq import DefaultIP, Xlnk
from pprint import pprint
from . import tools

__author__ = 'Fassial'
__copyright__ = 'Copyright 2019, WHU'
__email__ = 'fassial19991217@gmail.com'

MAX_C_SG_LENGTH_WIDTH = 26
BufAddrLow = 2
BufAddrUp = 3
CONTROL = 6

class _DMASGChannel:
	"""Drives a single channel of the Xilinx AXI DMA
	This driver is designed to be used in conjunction with the
	`pynq.allocate()` method of memory allocation. The channel has
	main functions `transfer` and `wait` which start and wait for
	the transfer to finish respectively. If interrupts are enabled
	there is also a `wait_async` coroutine.
	This class should not be constructed directly, instead used
	through the AxiDMA class.
	"""
	def __init__(self, mmio, offset, size, flush_before, dma_sg, interrupt = None):
		self._mmio = mmio
		self._offset = offset
		self._interrupt = interrupt
		self._flush_before = flush_before
		self._size = size
		self.dma_sg = dma_sg
		self.active_buffer = None
		self.descriptor = []

	@property
	def running(self):
		"""
		True if the DMA engine is currently running
		"""
		return self._mmio.read(self._offset + 4) & 0x01 == 0x00

	@property
	def idle(self):
		"""
		True if the DMA engine is idle
		`transfer` can only be called when the DMA is idle
		"""
		return self._mmio.read(self._offset + 4) & 0x02 == 0x02

	def start(self):
		"""
		Start the DMA engine if stopped
		"""
		if self._interrupt:
			self._mmio.write(self._offset, 0x1001)
		else:
			self._mmio.write(self._offset, 0x0001)
		while not self.running:
			pass

	def stop(self):
		"""
		Stops the DMA channel and aborts the current transfer
		"""
		self._mmio.write(self._offset, 0x0000)
		while self.running:
			pass

	def _clear_interrupt(self):
		self._mmio.write(self._offset + 4, 0x1000)

	def check_buf_in_desclist(self, buffer):
		for descriptor in self.descriptor:
			if (descriptor[BufAddrLow] == (buffer.physical_address & 0xffffffff)) and (descriptor[BufAddrUp] == ((buffer.physical_address >> 32) & 0xffffffff)):
				return True
		return False

	def transferS2MM(self, data_size, restart = 0):
		"""
		Transfer memory with the DMA
		Transfer must only be called when the channel is idle.
		Parameters
		----------
		data_size : n_4bytes
		restart   : restart flag
		"""
		if (data_size << 2) > self._size:
			raise ValueError('Transferred array is {} bytes, which exceeds the maximum DMA buffer size {}.'.format(array.nbytes, self._size))
		if restart == 1:
			Control = (1 << 27) | (data_size << 2)		# enable TXSOF
			descriptor, buffer = tools.alloc_single_loop_descriptor(Control, data_size)
			self.descriptor.append(descriptor)
			self.active_buffer = buffer
		else:
			descriptor = self.descriptor[0]	# get the head
			descriptor[CONTROL] = descriptor[CONTROL] & 0xf7ffffff
			buffer = self.active_buffer
		tools.print_descriptor_attr(descriptor)
		# @ 1
		if self._mmio.read(self._offset + 0x04) & 0x01 == 0x0 or self._mmio.read(self._offset + 0x00) & 0x01 == 0x1:
			self._mmio.write(self._offset + 0x00, (self._mmio.read(self._offset + 0x00) & 0xfffffffe))
			while self._mmio.read(self._offset + 0x04) & 0x01 == 0x0 or self._mmio.read(self._offset + 0x00) & 0x01 == 0x1:
				pass
		tools.print_dma_status(self.dma_sg)
		# write S2MM Current Descriptor Pointer. Lower
		print(descriptor.physical_address)
		self._mmio.write(self._offset + 0x08, (descriptor.physical_address & 0xffffffff))
		# write S2MM Current Descriptor Pointer. Upper
		self._mmio.write(self._offset + 0x0c, ((descriptor.physical_address >> 32) & 0xffffffff))
		# @ 2
		# setting the run/stop bit to 1 (S2MM_DMACR.RS =1)
		# self._mmio.write(0x30, (self._mmio.read(0x30) & 0xffffffef))
		# self._mmio.write(0x30, (self._mmio.read(0x30) | 0x1))
		self._mmio.write(self._offset + 0x00, (self._mmio.read(0x30) | 0x11))
		while self._mmio.read(self._offset + 0x04) & 0x01 != 0x0:
			pass
		# @ 3
		# enable interrupts by writing a 1 to S2MM_DMACR.IOC_IrqEn and S2MM_DMACR.Err_IrqEn
		self._mmio.write(self._offset + 0x00, (self._mmio.read(self._offset + 0x00) | 0x5000))
		# @ 4
		# write a valid address to the Tail Descriptor register
		# self._mmio.write(0x40, (descriptor.physical_address & 0xffffffff))
		# self._mmio.write(0x44, ((descriptor.physical_address >> 32) & 0xffffffff))
		# Program the Tail Descriptor register with some value which is not a part of the BD chain.
		self._mmio.write(self._offset + 0x10, (descriptor.physical_address & 0xffffffff))
		# @ 5
		# end
		tools.print_dma_status(self.dma_sg)
		return buffer

class DMA_SG(DefaultIP):

	def __init__(self, description, *args, **kwargs):
		"""Create an instance of the DMA SG Driver
		Parameters
		----------
		description : dict
			The entry in the IP dict describing the DMA engine
		"""
		if type(description) is not dict or args or kwargs:
			raise RuntimeError('You appear to want the old DMA SG driver which has been deprecated and moved to pynq.lib.deprecated')
		super().__init__(description=description)

		if 'parameters' in description and 'c_sg_length_width' in description['parameters']:
			self.buffer_max_size = 1 << int(description['parameters']['c_sg_length_width'])
		else:
			self.buffer_max_size = 1 << MAX_C_SG_LENGTH_WIDTH
			message = 'Failed to find parameter c_sg_length_width; users should really use *.hwh files for overlays.'
			warnings.warn(message, UserWarning)

		if 'mm2s_introut' in description['interrupts']:
			self.sendchannel = _DMASGChannel(self.mmio, 0x0, self.buffer_max_size, True, self, self.mm2s_introut)
		else:
			self.sendchannel = _DMASGChannel(self.mmio, 0x0, self.buffer_max_size, True, self)

		if 's2mm_introut' in description['interrupts']:
			self.recvchannel = _DMASGChannel(self.mmio, 0x30, self.buffer_max_size, False, self, self.s2mm_introut)
		else:
			self.recvchannel = _DMASGChannel(self.mmio, 0x30, self.buffer_max_size, False, self)

	def get_mmio(self):
		return self.mmio

	bindto = ['xilinx.com:ip:axi_dma:7.1']
