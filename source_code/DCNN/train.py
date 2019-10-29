import csv
import numpy as np
import pandas as pd
from matplotlib import pyplot as plt
import os
import tensorflow as tf
import math
from sklearn.model_selection import train_test_split
from sklearn.utils.multiclass import unique_labels
from sklearn.metrics import confusion_matrix
from sklearn.preprocessing import StandardScaler
from keras.models import Model, load_model
from keras.callbacks import ModelCheckpoint
from keras.models import Sequential
from keras.layers import Input,Dense,LSTM,Bidirectional,Dropout,Flatten,Masking
from keras.layers.convolutional import Conv1D
from keras.layers.convolutional import MaxPooling1D
import keras
import warnings
warnings.filterwarnings('ignore')

def predict(X,sess,logits,n_steps,n_inputs,seq_len):
    X = X.reshape((-1, n_steps, n_inputs))
    yprob=sess.run(logits, feed_dict={x: X,seq_length: seq_len})
    y=[]
    for nowy in yprob:
        y.append(np.argmax(nowy))
    return [y,yprob]


def plot_confusion_matrix(y_true, y_pred, classes,
                          normalize=False,
                          title=None,
                          cmap=plt.cm.Blues):
    """
    This function prints and plots the confusion matrix.
    Normalization can be applied by setting `normalize=True`.
    """
    if not title:
        if normalize:
            title = 'Normalized confusion matrix'
        else:
            title = 'Confusion matrix, without normalization'

    # Compute confusion matrix
    cm = confusion_matrix(y_true, y_pred)
    # Only use the labels that appear in the data
    classes = classes[unique_labels(y_true, y_pred)]
    if normalize:
        cm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]
        print("Normalized confusion matrix")
    else:
        print('Confusion matrix, without normalization')

    print(cm)

    fig, ax = plt.subplots()
    im = ax.imshow(cm, interpolation='nearest', cmap=cmap)
    ax.figure.colorbar(im, ax=ax)
    # We want to show all ticks...
    ax.set(xticks=np.arange(cm.shape[1]),
           yticks=np.arange(cm.shape[0]),
           # ... and label them with the respective list entries
           xticklabels=classes, yticklabels=classes,
           title=title,
           ylabel='True label',
           xlabel='Predicted label')

    # Rotate the tick labels and set their alignment.
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right",
             rotation_mode="anchor")

    # Loop over data dimensions and create text annotations.
    fmt = '.2f' if normalize else 'd'
    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(j, i, format(cm[i, j], fmt),
                    ha="center", va="center",
                    color="white" if cm[i, j] > thresh else "black")
    fig.tight_layout()
    plt.show()
    return ax

def moving_average(a, n=3) :
    ret = np.cumsum(a, dtype=float)
    ret[n:] = ret[n:] - ret[:-n]
    return ret[n - 1:] / n

trainset_addr='./all-8-19/train/'

testset_addr='./all-8-19/test/'

#读取文件
def getset(set_addr,ifquiet=0):#是否读取静音区，是否不只是0-9，需要根据需要判断标识符
    files_num=0
    label_index=np.zeros((10,10))
    label_index[0]=[0,1,2,3,4,5,6,7,8,9]
    label_index[1]=[9,8,7,6,5,4,3,2,1,0]
    label_index[2]=[1,3,5,7,9,0,2,4,6,8]
    label_index[3]=[8,6,4,2,0,9,7,5,3,1]
    label_index[4]=[0,3,6,9,2,5,8,1,4,7]
    label_index[5]=[7,4,1,8,5,2,9,6,3,0]
    label_index[6]=[0,4,8,2,6,1,5,9,3,7]
    label_index[7]=[7,3,9,5,1,6,2,8,4,0]
    label_index[8]=[0,5,1,6,2,7,3,8,4,9]
    label_index[9]=[0,0,6,6,0,6,6,0,0,6]
    for (dirpath,dirnames,filenames) in os.walk(set_addr):
        for f in filenames:
            files_num=files_num+1

    set_df=[0]*files_num#数据的读取时的数据框
    label=np.zeros((files_num))
    index=0#当前已经处理了多少个文件
    scaler = StandardScaler()
    for (dirpath,dirnames,filenames) in os.walk(set_addr):
        for f in filenames:
            df1=pd.read_csv(dirpath+f,sep=',')
            set_df[index]=pd.DataFrame(df1.iloc[5:-5].values,columns=df1.columns)
            df=df1[5:-5].reset_index(drop=True)
            label[index]=f[0]#文件名开头表示是序列标签
            index=index+1

    maxlen_seg=0
    
    segments=[0]*files_num
    if(ifquiet==1):#需要静音区训练
        seq_length=np.zeros((files_num,20))
        Y=np.zeros((files_num,2,20))
    else:
        seq_length=np.zeros((files_num,10))
        Y=np.zeros((files_num,2,10))
    
    for file in range(files_num):
        df=set_df[file]
        data_seg=np.zeros((10,2,2))#10个段，0表示数字，1表示数字之后的静止区域

        data_seg[0][0][0]=0
        current_index=0#目前存了几段
        flag=0#标注是静音开始还是书写开始

        for row in range(df.shape[0]):
            if(df.Keydown[row]!=str(-1)):#因为有D，所以是字符串格式的
                if(flag==0):#在数字中，遇到了写的结尾，静音的开始
                    data_seg[current_index][0][1]=row-1
                    data_seg[current_index][1][0]=row+1#静音开始
                    flag=(flag+1)%2
                else:#静音区结束，数字的开始
                    data_seg[current_index][1][1]=row-1
                    current_index=current_index+1
                    data_seg[current_index][0][0]=row+1
                    flag=(flag+1)%2
        data_seg[9][1][1]=df.shape[0]-1

        for i in range(10):
            if((data_seg[i][0][1]-data_seg[i][0][0])>maxlen_seg):
                maxlen_seg=data_seg[i][0][1]-data_seg[i][0][0]
            if((data_seg[i][1][1]-data_seg[i][1][0])>maxlen_seg):
                maxlen_seg=data_seg[i][1][1]-data_seg[i][1][0]

        number_segs=np.zeros((10,int(maxlen_seg),3))
        quiet_segs=np.zeros((10,int(maxlen_seg),3))

        for i in range(10):
            if(i==0):#如果是第0段数字，开头的50ms去掉，相当于这里面是5个采样点
                number_segs[i][0:int(data_seg[i][0][1])-int(data_seg[i][0][0])]=df[['ACCx','ACCy','ACCz']][int(data_seg[i][0][0]):int(data_seg[i][0][1])]
                #number_segs[i][0:(int(data_seg[i][0][1])-int(data_seg[i][0][0])-50)]=scaler.fit_transform(number_segs[i][0:(int(data_seg[i][0][1])-int(data_seg[i][0][0])-50)])
            else:
                number_segs[i][0:(int(data_seg[i][0][1])-int(data_seg[i][0][0]))]=df[['ACCx','ACCy','ACCz']][int(data_seg[i][0][0]):int(data_seg[i][0][1])]
                #number_segs[i][0:(int(data_seg[i][0][1])-int(data_seg[i][0][0]))]=scaler.fit_transform(number_segs[i][0:(int(data_seg[i][0][1])-int(data_seg[i][0][0]))])
            if(i==9):#最后5个采样点不要
                quiet_segs[i][0:(int(data_seg[i][1][1])-int(data_seg[i][1][0]))]=df[['ACCx','ACCy','ACCz']][int(data_seg[i][1][0]):int(data_seg[i][1][1])]
            else:
                quiet_segs[i][0:(int(data_seg[i][1][1])-int(data_seg[i][1][0]))]=df[['ACCx','ACCy','ACCz']][int(data_seg[i][1][0]):int(data_seg[i][1][1])]
        if(ifquiet==1):#如果需要静音区，就返回包括了静音区部分，否则不返回静音区
            segments[file]=np.zeros((20,int(maxlen_seg),3))
            #每个样本里面有20段，每段的属性有Y[0]表示类型，Y[1]表示长度,数字用0-9表示，间隔用10表示
            for i in range(10):
                segments[file][2*i][0:number_segs[i].shape[0]]=number_segs[i]
                Y[file][0][2*i]=i#如果是i，表示是数字
                Y[file][1][2*i]=data_seg[i][0][1]-data_seg[i][0][0]
            for i in range(10):
                segments[file][2*i+1][0:quiet_segs[i].shape[0]]=quiet_segs[i]
                Y[file][0][2*i+1]=-1#间隔就是0
                Y[file][1][2*i+1]=data_seg[i][1][1]-data_seg[i][1][0]

            seq_length[file]=Y[file][1]#Y[1]表示长度
        else:
            segments[file]=np.zeros((10,int(maxlen_seg),3))
            #每个样本里面有10段，每段的属性有Y[0]表示类型，Y[1]表示长度,数字用0-9表示
            
            for i in range(10):
                segments[file][i][0:number_segs[i].shape[0]]=StandardScaler().fit_transform(number_segs[i])
                Y[file][0][i]=label_index[int(label[file])][i]#标识
                Y[file][1][i]=data_seg[i][0][1]-data_seg[i][0][0]
            seq_length[file]=Y[file][1]#Y[1]表示长度
    return (Y,segments,maxlen_seg,files_num,seq_length)

def draw_pic(number_segs,index):
    MAorder=7
    
    #移动平均处理,下标为0..MAorder-1这部分数据是NaN，不能进行运算的！很麻烦
    ax=moving_average(number_segs[index,:,0],MAorder)
    az=moving_average(number_segs[index,:,2],MAorder)
    ay=moving_average(number_segs[index,:,1],MAorder)
    
      
    #加速度的积分是速度
    vx=np.zeros(len(ax)-MAorder+1)
    vz=np.zeros(len(az)-MAorder+1)
    vy=np.zeros(len(ay)-MAorder+1)
    vx[0]=ax[MAorder-1]#不然后面j-1越界了，没有初始值
    vz[0]=az[MAorder-1]
    vy[0]=ay[MAorder-1]
    enhancex=ax.mean()#抵消掉手抖的部分，静止时，测出来x轴自带-0.2左右的加速度，这个值不稳定，用均值代替
    enhancez=az.mean()#同理，抵消z轴上的静态加速度
    enhancey=ay.mean()
    for j in range(1,len(ax)-MAorder+1):
            vx[j]=vx[j-1]+ax[j+MAorder-1]-enhancex#当前速度=前一刻速度+ (加速度-补偿)
            vz[j]=vz[j-1]+az[j+MAorder-1]-enhancez#假设20ms内是匀加速
            vy[j]=vy[j-1]+ay[j+MAorder-1]-enhancey
    
    #位移  
    posy=np.zeros(len(vy))
    posx=np.zeros(len(vx))
    posz=np.zeros(len(vz))
    
    posx[0]=vx[0]#不然后面j-1越界了
    posz[0]=vz[0]
    posy[0]=vy[0]
    for j in range(1,len(vx)):
            posx[j]=posx[j-1]+vx[j]/2#当前位移=前一刻位移+现在速度，假设在20ms内匀速运动
            posz[j]=posz[j-1]+vz[j]/2
            posy[j]=posy[j-1]+vy[j]/2
    
    plt.subplot(311)
    plt.plot(range(0,len(ax)),ax,color="r",label="ax")
    plt.plot(range(0,len(ay)),ay,color="b",label="ay")
    plt.plot(range(0,len(az)),az,color="g",label="az")
    plt.hlines(0,min(min(ax),min(az)),max(max(ax),max(az)),colors="c",linestyles = "dashed")
    plt.title('The template is number '+ str(index))
    plt.legend()
    
    plt.subplot(312)
    plt.plot(range(0,len(vx)),vx,color="r",label="vx")
    plt.plot(range(0,len(vy)),vy,color="b",label="vy")
    plt.plot(range(0,len(vz)),vz,color="g",label="vz")
    plt.hlines(0,min(min(vx),min(vz)),max(max(vx),max(vz)),colors="c",linestyles = "dashed")
    plt.legend()
    
    plt.subplot(313)
    plt.scatter(-posz,posx)
    plt.show()

np.random.seed(seed=666)
#segments[i]装的是第i个文件的20个段落，长度在seq_length[i]中，标签是Y[0]
#拆散，拆成单一的文件
Y,segments,maxlen_seg_train,train_files_num,seq_length=getset(trainset_addr)
Y_for_test,segments_test,maxlen_seg_test,test_files_num,seq_length_test=getset(testset_addr)

maxlen=800
y_all=np.zeros((train_files_num*10))
X_all=np.zeros((train_files_num*10,int(maxlen),3))
for i in range(train_files_num):
    y_all[10*i:10*(i+1)]=Y[i][0]#标记,10个一组
    for j in range(10):  
        temp=segments[i][j][:,]
        #temp=StandardScaler().fit_transform(temp)
        X_all[10*i+j][0:segments[i][j].shape[0],:]=temp
seq_length=seq_length.reshape(train_files_num*10)


trainsize=0.7 #训练样本数目
permindex=np.random.permutation(len(y_all))
trainindex=permindex[0:int(trainsize*len(y_all))]#训练集下标
validindex=permindex[int(trainsize*len(y_all))+1:]#验证集下标


X_train=np.zeros((len(trainindex),int(maxlen),3))#这么多个训练样本，每个这么长
y_train=y_all[trainindex]#按照顺序的y
y_train=y_train.astype(np.int32)
X_train=X_all[trainindex]#按照顺序的x
seq_length_train=seq_length[trainindex]#序列长度
                
X_valid = np.zeros((len(validindex),int(maxlen),3))
y_valid=y_all[validindex]#按照顺序的y
y_valid=y_valid.astype(np.int32)
X_valid=X_all[validindex]#按照顺序的x
seq_length_valid=seq_length[validindex]


###########测试集合#################

y_test=np.zeros((test_files_num*10))
X_test=np.zeros((test_files_num*10,int(maxlen),3))
for i in range(test_files_num):
    y_test[10*i:10*(i+1)]=Y_for_test[i][0]
    for j in range(10):  
        temp=segments_test[i][j][:,]
        #temp=StandardScaler().fit_transform(temp)
        X_test[10*i+j][0:segments_test[i][j].shape[0],:]=temp
y_test=y_test.astype(np.int32)
seq_length_test=seq_length_test.reshape(test_files_num*10)



timesteps= maxlen#每次送的最大时间步数也就是句子单词个数，对于某个可能不要这么多步，多少步由seq_length决定！
features= 3#特征维度，也就是
n_outputs = 10

num_epoch=30
batch_size=200
y_train=keras.utils.to_categorical(y_train,n_outputs,dtype=np.int32)
y_valid=keras.utils.to_categorical(y_valid,n_outputs,dtype=np.int32)
y_test=keras.utils.to_categorical(y_test,n_outputs,dtype=np.int32)

iftrain=1
if(iftrain==1):

    model = Sequential()#构建序列model
    model.add(Conv1D(filters=128, kernel_size=15, activation='relu',input_shape=(timesteps,features)))
    model.add(Dropout(0.5))
    model.add(MaxPooling1D(pool_size=2))
    model.add(Bidirectional(LSTM(150,dropout=0.2, recurrent_dropout=0.2)))
    model.add(Dense(50, activation='relu'))
    model.add(Dropout(0.2))
    model.add(Dense(n_outputs, activation='softmax'))
    #metrics是准确度；loss是categorical_crossentropy
    model.compile(loss='categorical_crossentropy',optimizer='adam', metrics=['accuracy']) 

    modelpath='./model/all_style_CNN_BLSTM_model_800_scale_8_19.h5'
    #verbose=1打印日志；save_best_only=True自动保存最好的
    checkpointer = ModelCheckpoint(filepath=modelpath,
                                   verbose=1,
                                   save_best_only=True)
    #epochs是迭代次数；batch_size是每次送的样本数；validation_data是验证集
    history = model.fit(X_train, y_train,
                              epochs=num_epoch,
                              batch_size=batch_size,
                              shuffle=True,
                              validation_data=(X_valid, y_valid),
                              verbose=1, 
                              callbacks=[checkpointer]).history
    
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print('Accuracy: %f' % (accuracy*100))
    