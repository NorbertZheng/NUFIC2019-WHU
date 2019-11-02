import time
import serial
import logging
import binascii
import platform
from datetime import datetime
from SerialHelper import SerialHelper

if platform.system() == "Windows":
	from serial.tools import list_ports
else:
	import glob
	import os
	import re

n_packageblock = 400
n_block = 416
block_size = 32
n_packageblock_bytes = n_packageblock * block_size
n_block_bytes = n_block * block_size
tag_loc = n_packageblock_bytes + block_size - 1

class Serial(object):

	def __init__(self, port = "COM4", baudrate = "115200"):
		'''
		init parameters
		'''
		self.port = port
		self.baudrate = baudrate
		self.serial_receive_count = 0
		self.serial_receive_data = []
		self.serial_listbox = list()
		self.timestamp = time.time()
		self.dataleng = len(self.serial_receive_data)

		# enter your filename
		datafile = input('enter your filename(for example, test.csv): ')
		dt = datetime.now()
		nowtime_str = dt.strftime('%y-%m-%d-%I-%M-%S')
		self.datafile = nowtime_str + '_' + datafile
		self.tagfile = nowtime_str + '_tag_' + datafile

		# self.find_all_devices()
		self.ser = SerialHelper(Port = self.port, BaudRate = self.baudrate)
		self.ser.on_connected_changed(self.serial_on_connected_changed)

	def find_all_devices(self):
		'''
		find all serial devices
		'''
		self.find_all_serial_devices()

	def find_all_serial_devices(self):
		'''
		check serial devices according to platform
		'''
		try:
			if platform.system() == 'Windows':
				self.temp_serial = list()
				for com in list(list_ports.comports()):
					try:
						# self.print_com_attr(com)
						strCom = com.device + ": " + com.description
					except:
						continue
					self.temp_serial.append(strCom)
				# print(self.temp_serial)
				# can change GUI according to temp_serial
				self.serial_listbox = self.temp_serial
			elif platform.system() == "Linux":
				self.temp_serial = list()
				self.temp_serial = self.find_sub_tty()
				# can change GUI according to temp_serial
				self.serial_listbox = self.temp_serial
		except Exception as e:
			logging.error(e)

	def find_usb_tty(self, vendor_id=None, product_id=None):
		'''
		find serial devices in Linux
		'''
		tty_devs = list()
		for dn in glob.glob('/sys/bus/usb/devices/*'):
			try:
				vid = int(open(os.path.join(dn, "idVendor")).read().strip(), 16)
				pid = int(open(os.path.join(dn, "idProduct")).read().strip(), 16)
				if ((vendor_id is None) or (vid == vendor_id)) and ((product_id is None) or (pid == product_id)):
					dns = glob.glob(os.path.join(
						dn, os.path.basename(dn) + "*"))
					for sdn in dns:
						for fn in glob.glob(os.path.join(sdn, "*")):
							if re.search(r"\/ttyUSB[0-9]+$", fn):
								tty_devs.append(os.path.join(
									"/dev", os.path.basename(fn)))
			except Exception as ex:
				pass
		return tty_devs

	def print_com_attr(self, com):
		print(com)
		try:
			print("\tdevice:\t" + com.device)
		except:
			pass
		try:
			print("\tname:\t" + com.name)
		except:
			pass
		try:
			print("\tdescription:\t" + com.description)
		except:
			pass
		try:
			print("\thwid:\t" + com.hwid)
		except:
			pass
		try:
			print("\tvid:\t" + com.vid)
		except:
			pass
		try:
			print("\tpid:\t" + com.pid)
		except:
			pass
		try:
			print("\tserial_number:\t" + com.serial_number)
		except:
			pass
		try:
			print("\tlocation:\t" + com.location)
		except:
			pass
		try:
			print("\tmanufacturer:\t" + com.manufacturer)
		except:
			pass
		try:
			print("\tproduct:\t" + com.product)
		except:
			pass
		try:
			print("\tinterface:\t" + com.interface)
		except:
			pass

	def serial_clear(self):
		'''
		clear serial receive text
		'''
		self.serial_receive_count = 0

	def serial_toggle(self, port = "COM4", baudrate = "115200", parity = "N", databit = "8", stopbit = "1", open = 1):
		'''
		open / close serial devices
		'''
		if (open == 1):
			try:
				self.port = port
				self.baudrate = baudrate
				self.parity = parity
				self.databit = databit
				self.stopbit = stopbit
				self.ser = SerialHelper(Port = self.port, BaudRate = self.baudrate, ByteSize = self.databit, Parity = self.parity, Stopbits = self.stopbit)
				self.ser.on_connected_changed(self.serial_on_connected_changed)
			except Exception as e:
				logging.error(e)
				# can change GUI according to error
		else:
			self.ser.disconnect()
			# can change GUI according to disconnect

	def serial_send(self, send_data, hex_flag = 1):
		'''
		serial data send
		'''
		if (hex_flag == 1):
			send_data = send_data.replace(" ", "").replace("\n", "0A").replace("\r", "0D")
			self.ser.write(send_data, True)
		else:
			self.ser.write(send_data)

	def serial_on_connected_changed(self, is_connected):
		'''
		when serial devices connection changed, we will call this method
		'''
		if is_connected:
			self.ser.connect()
			if self.ser._is_connected:
				# can change GUI according to connection state
				self.ser.on_data_received(self.serial_on_data_received)
				print("Connected")
			else:
				# can change GUI according to connection state
				pass
		else:
			self.ser.disconnect()
			# can change GUI according to connection state
			print("Disconnected")

	def serial_on_data_received(self, data):
		'''
		when serial devices receive data, we will call this method
		'''
		'''
		# print([hex(x)[2:].zfill(2) for x in data])
		self.serial_receive_data.extend([hex(x)[2:].zfill(2) for x in data])
		# print(len(self.serial_receive_data))
		csv_wrdata = ""
		self.currDataleng = len(self.serial_receive_data)
		self.currTimestamp = time.time()
		if ((self.currTimestamp - self.timestamp) > 5):
			# complete data
			temp_serial_receive_data = self.serial_receive_data[:self.dataleng - 1]
			for j in range(n_packageblock_bytes - self.dataleng):
				temp_serial_receive_data.append('00')
			for i in range(n_packageblock_bytes):
				if (i % block_size) == block_size - 1:
					csv_wrdata += temp_serial_receive_data[i] + "\n"
					print(temp_serial_receive_data[i], end = "\n")
				else:
					csv_wrdata += temp_serial_receive_data[i] + ","
					print(temp_serial_receive_data[i], end = " ")
			with open(self.datafile, "a+") as f:
				f.write(csv_wrdata)
			# label
			tag = int(input("tag: "), 10)
			with open(self.tagfile, "a+") as f:
				f.write(tag + "\n")
			self.timestamp = time.time()
			self.serial_receive_data = self.serial_receive_data[self.dataleng:]
			self.dataleng = len(self.serial_receive_data)
			print(self.serial_receive_data)
		else:
			# self.serial_receive_data has already been updated
			self.dataleng = len(self.serial_receive_data)
			self.timestamp = time.time()
			print(self.timestamp)
		'''
		self.currTimestamp = time.time()
		if ((self.currTimestamp - self.timestamp) > 5):
			self.serial_receive_data = []
		# print([hex(x)[2:].zfill(2) for x in data])
		self.serial_receive_data.extend([hex(x)[2:].zfill(2) for x in data])
		# print(len(self.serial_receive_data))
		csv_wrdata = ""
		if (len(self.serial_receive_data) >= n_block_bytes):
			for i in range(n_packageblock_bytes):
				if (i % block_size) == block_size - 1:
					csv_wrdata += self.serial_receive_data[i] + "\n"
					print(self.serial_receive_data[i], end = "\n")
				else:
					csv_wrdata += self.serial_receive_data[i] + ","
					print(self.serial_receive_data[i], end = " ")
			with open(self.datafile, "a+") as f:
				f.write(csv_wrdata)
			print("tag: " + self.serial_receive_data[tag_loc])
			with open(self.tagfile, "a+") as f:
				f.write(self.serial_receive_data[tag_loc] + "\n")
			self.serial_receive_data = self.serial_receive_data[n_block_bytes:]
			print(self.serial_receive_data)
		else:
			pass
		# update timestamp
		self.timestamp = time.time()

if __name__ == '__main__':
	serial = Serial()
	count = 0
	while count < 9:
		pass
		# print("Count: %s"%count)
		# stime.sleep(1)
		# count += 1
