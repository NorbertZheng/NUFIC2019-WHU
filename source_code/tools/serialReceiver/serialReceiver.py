import sys
import csv
import serial
import threading
import binascii
from datetime import datetime

g = 9.8
start_func = 0x50
start_func_flag = False
serialPort = 'com6'		# COM
baudRate = 115200		# BAUD_RATE
is_exit = False
data_bytes = bytearray()

class SerialPort:

	def __init__(self, port, baudrate, timeout = 0.5):
		self.port = serial.Serial(port, baudrate, timeout = timeout)
		self.port.close()
		if not self.port.isOpen():
			self.port.open()

	def port_open(self):
		if not self.port.isOpen():
			self.port.open()

	def port_close(self):
		self.port.close()

	def send_data(self):
		self.port.write('')

	def read_data(self):
		global is_exit, data_bytes
		while not is_exit:
			count = self.port.inWaiting()
			if count > 0:
				rec_str = self.port.read(count)
				data_bytes = data_bytes + rec_str
				# print('the amount of all received bytes: ' + str(len(data_bytes))+'\nthe amount of this received bytes: ' + str(len(rec_str)))
				# print(str(datetime.now()), ':', binascii.b2a_hex(rec_str))

def main():
	global g, start_func, start_func_flag
	# open serial
	m_Serial = SerialPort(serialPort, baudRate)

	# enter your filename
	filename = input('enter your filename(for example, test.csv): ')
	dt = datetime.now()
	nowtime_str = dt.strftime('%y-%m-%d-%I-%M-%S')
	filename = nowtime_str + '_' + filename
	out = open(filename, 'a+')
	csv_writer = csv.writer(out)

	# start data read thread
	t1 = threading.Thread(target = m_Serial.read_data)
	t1.setDaemon(True)
	t1.start()

	while not is_exit:
		# main thread: modify the data from Serial
		data_len = len(data_bytes)
		i = 0
		csv_row = []
		while (i < data_len - 1):
			# print(data_bytes[i])
			if data_bytes[i] == 0x55:
				# for write one datagram-set
				if data_bytes[i + 1] == start_func:
					if csv_row != []:
						try:
							csv_writer.writerow(csv_row)
						except Exception as e:
							raise e
					csv_row = []
				if data_bytes[i + 1] == 0x50:
					# time
					YY = str(data_bytes[i + 2])
					MM = str(data_bytes[i + 3])
					DD = str(data_bytes[i + 4])
					HH = str(data_bytes[i + 5])
					MM = str(data_bytes[i + 6])
					SS = str(data_bytes[i + 7])
					MS = str(data_bytes[i + 8:i + 9].reverse())
					csv_row.extend([YY, MM, DD, HH, MM, SS, MS])
					print(hex(data_bytes[i + 1]) + "\t" + YY + "\t" + MM + "\t" + DD + "\t" + HH + "\t" + SS + "\t" + MS)
					# for start_func
					if not start_func_flag:
						start_func_flag = True
						start_func = data_bytes[i + 1]
					# skip 1 datagram
					i = i + 11
				elif data_bytes[i + 1] == 0x51:
					# acceleration
					ax = str(((data_bytes[i + 3] << 8) + data_bytes[i + 2]) / 32768 * 16 * g)
					ay = str(((data_bytes[i + 5] << 8) + data_bytes[i + 4]) / 32768 * 16 * g)
					az = str(((data_bytes[i + 7] << 8) + data_bytes[i + 6]) / 32768 * 16 * g)
					T = str(((data_bytes[i + 9] << 8) + data_bytes[i + 8]) / 100)
					csv_row.extend([ax, ay, az, T])
					print(hex(data_bytes[i + 1]) + "\t" + ax + "\t" + ay + "\t" + az + "\t" + T + "℃")
					# for start_func
					if not start_func_flag:
						start_func_flag = True
						start_func = data_bytes[i + 1]
					# skip 1 datagram
					i = i + 11
				elif data_bytes[i + 1] == 0x52:
					wx = str(((data_bytes[i + 3] << 8) + data_bytes[i + 2]) / 32768 * 2000)
					wy = str(((data_bytes[i + 5] << 8) + data_bytes[i + 4]) / 32768 * 2000)
					wz = str(((data_bytes[i + 7] << 8) + data_bytes[i + 6]) / 32768 * 2000)
					T = str(((data_bytes[i + 9] << 8) + data_bytes[i + 8]) / 100)
					csv_row.extend([wx, wy, wz, T])
					print(hex(data_bytes[i + 1]) + "\t" + wx + "\t" + wy + "\t" + wz + "\t" + T + "℃")
					# for start_func
					if not start_func_flag:
						start_func_flag = True
						start_func = data_bytes[i + 1]
					# skip 1 datagram
					i = i + 11
				elif data_bytes[i + 1] == 0x53:
					Roll = str(((data_bytes[i + 3] << 8) + data_bytes[i + 2]) / 32768 * 180)
					Pitch = str(((data_bytes[i + 5] << 8) + data_bytes[i + 4]) / 32768 * 180)
					Yaw = str(((data_bytes[i + 7] << 8) + data_bytes[i + 6]) / 32768 * 180)
					T = str(((data_bytes[i + 9] << 8) + data_bytes[i + 8]) / 100)
					csv_row.extend([Roll, Pitch, Yaw, T])		# somthing is wrong with T
					print(hex(data_bytes[i + 1]) + "\t" + Roll + "\t" + Pitch + "\t" + Yaw + "\t" + T + "℃")
					# for start_func
					if not start_func_flag:
						start_func_flag = True
						start_func = data_bytes[i + 1]
					# skip 1 datagram
					i = i + 11
				elif data_bytes[i + 1] == 0x56:
					P = str(((data_bytes[i + 5] << 24) + (data_bytes[i + 4] << 16) + (data_bytes[i + 3] << 8) + data_bytes[i + 2]))
					H = str(((data_bytes[i + 9] << 24) + (data_bytes[i + 8] << 16) + (data_bytes[i + 7] << 8) + data_bytes[i + 6]))
					csv_row.extend([P, H])
					print(hex(data_bytes[i + 1]) + "\t" + P + "(Pa)" + "\t" + H + "(cm)")
					# for start_func
					if not start_func_flag:
						start_func_flag = True
						start_func = data_bytes[i + 1]
					# skip 1 datagram
					i = i + 11
				else:
					print(hex(data_bytes[i + 1]))
					i = i + 1
			else:
				i = i + 1

if __name__ == '__main__':
	main()
