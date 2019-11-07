import csv
import numpy as np
import matplotlib.pyplot as plt

TOTALSET = []
TOTAL_COUNT = 0
PROCESSEDSET = []
ColorMap = ['red', 'green', 'gray']

class Point:
	
	def __init__(self, number, attr, cluster = None, labeled = 0):
		self.number = number
		self.labeled = labeled
		self.attr = attr
		self.cluster = cluster
		
	def __str__(self):
		attr_cluster_str = ''
		for i in range(len(self.attr)):
			attr_cluster_str = attr_cluster_str + str(self.attr[i]) + ", "
		attr_cluster_str += self.cluster
		return str(self.number) + "(" + attr_cluster_str + ")"

def loadData(fileName):
	global TOTALSET, TOTAL_COUNT
	TOTALSET = []
	TOTAL_COUNT = 0
	XMat = []
	with open(fileName, "r", encoding = "utf-8") as f:
		reader = csv.reader(f)
		cursor = 0
		for row in reader:
			point = Point(cursor, row[0:3], row[3], 1)
			XMat.append(row[0:3])
			TOTALSET.append(point)
			cursor += 1
		TOTAL_COUNT = cursor
	#for i in TOTALSET:
	#	print(i)
	XMat = np.array(XMat).astype(np.float)
	return XMat.T
	
def centralizeMat(XMat):
	average = np.mean(XMat, axis = 1)
	average = np.tile(average, (np.shape(XMat)[1], 1)).T
	#print(average)
	XMat = XMat - average
	return XMat
	
def pca(XMat, k):
	global PROCESSEDSET
	PROCESSEDSET = []
	if k > np.shape(XMat)[0]:
		print("k > d!")
		return
	XMat = centralizeMat(XMat)
	print(np.shape(XMat))
	covX = np.cov(XMat)
	# print(covX, end = "\n\n")
	featureValue, featureVec=  np.linalg.eig(covX)
	#print(featureValue, end = "\n\n")
	#print(featureVec)
	sortedDimIndex = np.argsort(-featureValue)
	WMat = np.matrix(featureVec.T[sortedDimIndex[0:k]])
	# print("WMat: ")
	print(np.shape(WMat))
	#print(featureVec)
	#print(WMat)
	ZMat = WMat * XMat
	#print(ZMat)
	return ZMat
	
def plotDisp(ZMat):
	global TOTALSET, ColorMap
	if len(ZMat) > 2:
		print("Dimension too high!")
		return
	elif len(ZMat) == 2:
		figure = plt.figure()
		ax = figure.add_subplot(111)
		clusterType = []
		clusterX = []
		clusterY = []
		print(np.shape(ZMat)[1])
		for i in range(np.shape(ZMat)[1]):
			if TOTALSET[i].cluster not in clusterType:
				clusterType.append(TOTALSET[i].cluster)
				newClusterX = []
				newClusterY = []
				newClusterX.append(ZMat[0, i])
				newClusterY.append(ZMat[1, i])
				clusterX.append(newClusterX)
				clusterY.append(newClusterY)
			else:
				index = clusterType.index(TOTALSET[i].cluster)
				clusterX[index].append(ZMat[0, i])
				clusterY[index].append(ZMat[1, i])
		#print(clusterType)
		#print(clusterX)
		#print(clusterY)
		for i in range(len(clusterType)):
			ax.scatter(clusterX[i], clusterY[i], s = 50, c = ColorMap[i], marker='x')
		plt.xlabel('x1'); plt.ylabel('x2');
		plt.savefig("THREE2TWO.png")
		plt.show()
	elif len(ZMat) == 1:
		figure = plt.figure()
		ax = figure.add_subplot(111)
		clusterType = []
		clusterX = []
		clusterY = []
		print(np.shape(ZMat)[1])
		for i in range(np.shape(ZMat)[1]):
			if TOTALSET[i].cluster not in clusterType:
				clusterType.append(TOTALSET[i].cluster)
				newClusterX = []
				newClusterY = []
				newClusterX.append(ZMat[0, i])
				newClusterY.append(1)
				clusterX.append(newClusterX)
				clusterY.append(newClusterY)
			else:
				index = clusterType.index(TOTALSET[i].cluster)
				clusterX[index].append(ZMat[0, i])
				clusterY[index].append(1)
		#print(clusterType)
		#print(clusterX)
		#print(clusterY)
		for i in range(len(clusterType)):
			ax.scatter(clusterX[i], clusterY[i], s = 50, c = ColorMap[i], marker='x')
		plt.xlabel('x1'); plt.ylabel('x2');
		plt.savefig("TWO2ONE.png")
		plt.show()	
	
def main():
	fileName = "../dataset2_data_mining_course.csv"
	XMat = loadData(fileName)
	k = 2
	return pca(XMat, k)
	
if __name__ == "__main__":
	ZMat = main()
	plotDisp(ZMat)