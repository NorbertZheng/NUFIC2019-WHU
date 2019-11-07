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
DATAFILE = "1.csv"

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
	all_A = get_all_A(data)
	all_loc = get_all_loc(all_A)
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

def get_all_A(data):
	data = data[:, AX_LOW:AZ_HIGH_PLUS1]
	for i in range(np.shape(data)[0]):
		data[i, 0] = (data[i, 0] + ((data[i, 1]) << 8)) if ((data[i, 1]) < (2 ** 7)) else -((2 ** 16) - (data[i, 0] + ((data[i, 1]) << 8)))
		data[i, 1] = (data[i, 2] + ((data[i, 3]) << 8)) if ((data[i, 3]) < (2 ** 7)) else -((2 ** 16) - (data[i, 2] + ((data[i, 3]) << 8)))
		data[i, 2] = (data[i, 4] + ((data[i, 5]) << 8)) if ((data[i, 5]) < (2 ** 7)) else -((2 ** 16) - (data[i, 4] + ((data[i, 5]) << 8)))
	data = (data[:, 0:3]).astype(np.float64)
	data = data / 32768 * 16 * g
	return data

def get_all_loc(all_A):
	all_loc = np.zeros(np.shape(all_A))
	all_v = np.zeros(np.shape(all_A))
	for i in range(1, np.shape(all_A)[0]):
		all_loc[i, :], all_v[i, :] = update_loc(all_loc[i - 1, :], all_v[i - 1, :], all_A[i - 1, :])
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
