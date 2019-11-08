import math
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

from pca import pca

k = 2
g = 9.8
FREQ = 200
period = 1 / FREQ
AX_LOW = 8
AZ_HIGH_PLUS1 = 14
ROLL_LOW = 24
YAW_HIGH_PLUS1 = 30
DATAFILE = "2.csv"

def data_graph_generator(datafile):
	alldata = []
	with open(datafile, "r") as f:
		line = f.readline()
		while (line) != "":
			alldata.append([int(x, 16) for x in line.strip("\n").split(",")])
			line = f.readline()
	alldata = np.array(alldata)
	alldata = [alldata[(400 * i):(400 * (i + 1)),] for i in range(np.shape(alldata)[0] // 400)]
	for i in range(len(alldata)):
		loc = data_graph(alldata[i])
		# print(np.shape(loc))
		plotDisp3D(loc)

def data_graph(data):
	all_A, stop_ptr = get_all_A(data)
	for i in all_A.tolist():
		print(i)
	all_loc = get_all_loc(all_A, stop_ptr)
	return all_loc

def plotDisp3D(all_loc):
	fig = plt.figure()
	ax = plt.gca(projection='3d')
	ax.plot(all_loc[:, 0], all_loc[:, 1], all_loc[:, 2])
	plt.show()

def plotDisp2D(all_loc):
	ZMat = pca(all_loc.T, k).T
	figure = plt.figure()
	ax = figure.add_subplot(111)
	ax.scatter(ZMat[:, 0].tolist(), ZMat[:, 1].tolist(), s = 50, c = 'green', marker='.')
	plt.xlabel('x1'); plt.ylabel('x2');
	plt.savefig("THREE2TWO.png")
	plt.show()

def Euler2Rotation(phi, theta, psi):
	'''
	@Param:
		phi		: Yaw
		theta	: Pitch
		psi		: Roll
	@Ret:
		Rotation Matrix
	'''
	RotationMatrix = np.zeros((3, 3)).astype(np.float64)
	RotationMatrix[0, 0] = np.cos(theta) * np.cos(phi)
	RotationMatrix[1, 0] = np.cos(theta) * np.sin(phi)
	RotationMatrix[2, 0] = -np.sin(theta)
	RotationMatrix[0, 1] = (np.sin(psi) * np.sin(theta) * np.cos(phi)) - (np.cos(psi) * np.sin(phi))
	RotationMatrix[1, 1] = (np.sin(psi) * np.sin(theta) * np.sin(phi)) + (np.cos(psi) * np.cos(phi))
	RotationMatrix[2, 1] = np.sin(psi) * np.cos(theta)
	RotationMatrix[0, 2] = (np.cos(psi) * np.sin(theta) * np.cos(phi)) + (np.sin(psi) * np.sin(phi))
	RotationMatrix[1, 2] = (np.cos(psi) * np.sin(theta) * np.sin(phi)) - (np.sin(psi) * np.cos(phi))
	RotationMatrix[2, 2] = np.cos(psi) * np.cos(theta)
	return RotationMatrix

def get_g_acceleration(angle, stop_ptr):
	g_acceleration = np.zeros(np.shape(angle))
	# print(np.shape(g_acceleration))
	for i in range(stop_ptr):
		rotationMat = Euler2Rotation(angle[i, 2], angle[i, 1], angle[i, 0])
		g_acceleration[i, 0] = rotationMat[0, 2] * g
		g_acceleration[i, 1] = rotationMat[1, 2] * g
		g_acceleration[i, 2] = rotationMat[2, 2] * g
	# for i in range(np.shape(g_acceleration)[0]):
	# 	test = math.sqrt(g_acceleration[i, 0] ** 2 + g_acceleration[i, 1] ** 2 + g_acceleration[i, 2] ** 2)
	# 	print(test)
	return g_acceleration

def get_all_A(data):
	# get angle
	angle = data[:, ROLL_LOW:YAW_HIGH_PLUS1]
	for i in range(np.shape(angle)[0]):
		angle[i, 0] = (angle[i, 0] + ((angle[i, 1]) << 8))
		angle[i, 1] = (angle[i, 2] + ((angle[i, 3]) << 8))
		angle[i, 2] = (angle[i, 4] + ((angle[i, 5]) << 8))
	angle = (angle[:, 0:3]).astype(np.float64)
	angle = angle / 32768 * np.pi			# angle = angle / 32768 * 180
	stop_ptr = 0
	for i in range(np.shape(angle)[0]):
		if (angle[i, :] == 0).all():
			stop_ptr = i
			break
	# print(angle)
	g_acceleration = get_g_acceleration(angle, stop_ptr)
	# print(g_acceleration)
	# get acceleration
	acceleration = data[:, AX_LOW:AZ_HIGH_PLUS1]
	for i in range(np.shape(acceleration)[0]):
		acceleration[i, 0] = (acceleration[i, 0] + ((acceleration[i, 1]) << 8)) if ((acceleration[i, 1]) < (2 ** 7)) else -((2 ** 16) - (acceleration[i, 0] + ((acceleration[i, 1]) << 8)))
		acceleration[i, 1] = (acceleration[i, 2] + ((acceleration[i, 3]) << 8)) if ((acceleration[i, 3]) < (2 ** 7)) else -((2 ** 16) - (acceleration[i, 2] + ((acceleration[i, 3]) << 8)))
		acceleration[i, 2] = (acceleration[i, 4] + ((acceleration[i, 5]) << 8)) if ((acceleration[i, 5]) < (2 ** 7)) else -((2 ** 16) - (acceleration[i, 4] + ((acceleration[i, 5]) << 8)))
	acceleration = (acceleration[:, 0:3]).astype(np.float64)
	acceleration = acceleration / 32768 * 16 * g
	for i in acceleration.tolist():
		print(i)
	# for i in A.tolist():
	# 	print(i)
	acceleration -= g_acceleration
	return acceleration, stop_ptr

def get_all_loc(all_A, stop_ptr):
	all_loc = np.zeros(np.shape(all_A))
	all_v = np.zeros(np.shape(all_A))
	for i in range(1, stop_ptr):
		all_loc[i, :], all_v[i, :] = update_loc(all_loc[i - 1, :], all_v[i - 1, :], all_A[i - 1, :])
	if stop_ptr < np.shape(all_A)[0]:
		for i in range(stop_ptr, np.shape(all_A)[0]):
			all_loc[i, :], all_v[i, :] = all_loc[i - 1, :], all_v[i - 1, :]
	# print(all_loc, all_v)
	return all_loc

def update_loc(old_loc, old_v, curr_A):
	new_loc = old_loc + (old_v * period) + ((curr_A * period * period) / 2)
	new_v = old_v + (curr_A * period)
	return new_loc, new_v

def main():
	data_graph_generator(DATAFILE)

if __name__ == '__main__':
	main()
