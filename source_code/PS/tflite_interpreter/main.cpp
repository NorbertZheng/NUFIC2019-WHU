#include<stdio.h>
#include<stdlib.h>
#include<math.h>
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"
#include "tensorflow/lite/string_util.h"
#include "tensorflow/lite/mutable_op_resolver.h"

#define INPUT_DIM_0 1
#define INPUT_DIM_1 400
#define INPUT_DIM_2 3

// read txt file
void loadtxt(const char* txt, float* arr) {
	int i, j, k;
	FILE *fpRead=fopen(txt,"r");
	if(fpRead==NULL) {
		printf("%s File Open Failed\n", txt);
		exit(-1);
	}
	for(i = 0; i < INPUT_DIM_0; i++) {
		for (j = 0; j < INPUT_DIM_1; j++) {
			for (k = 0; k < INPUT_DIM_2 - 1; k++) {
				fscanf(fpRead, "%f,", &arr[(i * INPUT_DIM_1 * INPUT_DIM_2) + (j * INPUT_DIM_2) + k]);
			}
			fscanf(fpRead, "%f\n", &arr[(i * INPUT_DIM_1 * INPUT_DIM_2) + (j * INPUT_DIM_2) + k]);
		}
	}
	fclose(fpRead);
}

int main(void) {
	const char graph_path[64] = "test.tflite";
	const int num_threads = 1;
	std::string input_layer_type = "float";
	std::vector<int> sizes = {INPUT_DIM_0, INPUT_DIM_1, INPUT_DIM_2};
	float x,y;
	// loading model
	printf("Loading Model File ....\n");
	std::unique_ptr<tflite::FlatBufferModel> model(
		tflite::FlatBufferModel::BuildFromFile(graph_path));

	if(!model){
		printf("Failed to mmap model\n");
		exit(0);
	}
	printf("Model Loading Complete\n");
	// intepreter construct
	tflite::ops::builtin::BuiltinOpResolver resolver;
	std::unique_ptr<tflite::Interpreter> interpreter;
	tflite::InterpreterBuilder(*model, resolver)(&interpreter);

	if (!interpreter) {
		printf("Failed to construct interpreter\n");
		exit(0);
	}

	interpreter->UseNNAPI(false);

	if (num_threads != 1) {
		interpreter->SetNumThreads(num_threads);
	}
	printf("Interpreter Construct Complete\n");
	// format input
	float* arr = (float*) malloc ((INPUT_DIM_0 * INPUT_DIM_1 * INPUT_DIM_2) * sizeof(float));
	loadtxt("tmp.txt", arr);
	int input = interpreter->inputs()[0];
	interpreter->ResizeInputTensor(0, sizes);
	if (interpreter->AllocateTensors() != kTfLiteOk) {
		printf("Failed to allocate tensors\n");
		exit(0);
	}
	// format input
	for(unsigned int i = 0; i < INPUT_DIM_0; i++) {
		for (unsigned int j = 0; j < INPUT_DIM_1; j++) {
			for (unsigned int k = 0; k < INPUT_DIM_2 - 1; k++) {
				interpreter->typed_input_tensor<float>(0)[i, j, k] =  arr[(i * INPUT_DIM_1 * INPUT_DIM_2) + (j * INPUT_DIM_2) + k];
			}
		}
	}

	if (interpreter->Invoke() != kTfLiteOk) {
		std::printf("Failed to invoke!\n");
		exit(0);
	}
	int *output;
	output = interpreter->typed_output_tensor<int>(0);

	printf("Value: %d\n", *output);
	free(output);
	return 0;
}

