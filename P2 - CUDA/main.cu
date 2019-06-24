#include <iostream>
#include <cuda.h>


#define WIDTH 3833
#define HEIGHT 2160

bool checkResults(uchar4* rgba, uchar3* bgr, int size) {

    bool correct = true;

    for (int i=0; i < size; ++i) {
	// In case you want to see actual values
	if (i==3) {
		unsigned char x, y, z, w;
		x = rgba[i].x;
		y = rgba[i].y;
		z = rgba[i].z;
		w = rgba[i].w;
		std::cout << "First position x=" << (unsigned int)x << " y=" << (unsigned int)y << " z=" << (unsigned int)z << " w=" << (unsigned int)w << std::endl;
	}
        correct &= rgba[i].x == bgr[i].z;
        correct &= rgba[i].y == bgr[i].y;
        correct &= rgba[i].z == bgr[i].x;
        correct &= rgba[i].w == 255;
    }

    return correct;
}

__global__ void convertBGR2RGBA_1for(uchar3 *bgr, uchar4* rgba, int width, int height) {

	//int position = 0; // 0 is not correct. Compute each thread position;
	int position = threadIdx.x + blockIdx.x * blockDim.x;

	//printf("GPU - i = %d, j = %d\n", positionx, positiony);
	// Protection to avoid segmentation fault
	if (position < width * height) {	
		rgba[position].x = bgr[position].z;
		rgba[position].y = bgr[position].y;
		rgba[position].z = bgr[position].x;
		rgba[position].w = 255;
	}
}

__global__ void convertBGR2RGBA_2for(uchar3 *bgr, uchar4* rgba, int width, int height) {

	//int position = 0; // 0 is not correct. Compute each thread position;
	int positionx = threadIdx.x + blockIdx.x * blockDim.x;
	int positiony = threadIdx.y + blockIdx.y * blockDim.y;
	//int position = positiony * WIDTH + positionx;
	int position = positionx * HEIGHT + positiony;

	//printf("GPU - i = %d, j = %d\n", positionx, positiony);
	// Protection to avoid segmentation fault
	if (positionx < width ||  positiony < height) {
		rgba[position].x = bgr[position].z;
		rgba[position].y = bgr[position].y;
		rgba[position].z = bgr[position].x;
		rgba[position].w = 255;
	}
}

__global__ void convertBGR2RGBA_optBasic(uchar3 *bgr, uchar4* rgba, int width, int height) {

	int position = threadIdx.x + blockIdx.x * blockDim.x;
	uchar3 tempbgr = bgr[position];
	uchar4 temprgba;
	// Protection to avoid segmentation fault
	if (position < width * height) {	
		temprgba.x = tempbgr.z;
		temprgba.y = tempbgr.y;
		temprgba.z = tempbgr.x;
		temprgba.w = 255;
		rgba[position] = temprgba;
	}
}

__global__ void convertBGR2RGBA_optBasic2(uchar3 *bgr, uchar4* rgba, int width, int height) {

	int position = 2*(threadIdx.x + blockIdx.x * blockDim.x);

    if (position < width * height) {
        rgba[position+0].x = bgr[position+0].z;
        rgba[position+1].x = bgr[position+1].z;

        rgba[position+0].y = bgr[position+0].y;
        rgba[position+1].y = bgr[position+1].y;

        rgba[position+0].z = bgr[position+0].x;
        rgba[position+1].z = bgr[position+1].x;

        rgba[position+0].w = 255;
        rgba[position+1].w = 255;
    }
}


__global__ void convertBGR2RGBA_shared(uchar3 *bgr, uchar4* rgba, int width, int height) {

	extern __shared__ uchar3 shared_bgr[1024];
	extern __shared__ uchar4 shared_rgba[1024];

    int tid = threadIdx.x;

    int position = threadIdx.x + blockIdx.x * blockDim.x;

    if (position < width * height) {

        shared_bgr[tid] = bgr[position];

    	__syncthreads();

        shared_rgba[tid].x = shared_bgr[tid].z;
	    shared_rgba[tid].y = shared_bgr[tid].y;
	    shared_rgba[tid].z = shared_bgr[tid].x;
	    shared_rgba[tid].w = 255;

    	__syncthreads();
    	rgba[position] = shared_rgba[tid];
	}
}

int main() {

    uchar3 *h_bgr, *d_bgr;
    uchar4 *h_rgba, *d_rgba;

    int bar_widht = HEIGHT/3;

    // Alloc and generate BGR bars.
    h_bgr = (uchar3*)malloc(sizeof(uchar3)*WIDTH*HEIGHT);
    for (int i=0; i < WIDTH * HEIGHT; ++i) {
        if (i < bar_widht) {
		uchar3 temp = {255, 0, 0};
		h_bgr[i] = temp; 
	} else if (i < bar_widht*2) {
		uchar3 temp = {0, 255, 0};
		h_bgr[i] = temp;
	} else { 
		uchar3 temp = {0, 0, 255};
		h_bgr[i] = temp;
	}
    }

    // Alloc RGBA pointers
    h_rgba = (uchar4*)malloc(sizeof(uchar4)*WIDTH*HEIGHT);

    // Alloc gpu pointers
    cudaError_t error = cudaMalloc(&d_bgr, sizeof(uchar3) * WIDTH * HEIGHT);
    if (error != cudaSuccess) {
	std::cout << "Error in cudaMalloc" << std::endl;
    }

    error = cudaMalloc(&d_rgba, sizeof(uchar4) * WIDTH * HEIGHT);
    if (error != cudaSuccess) {
	std::cout << "Error in cudaMalloc" << std::endl;
    }
    
    // Copy data to GPU
    error = cudaMemcpy(d_bgr, h_bgr, sizeof(uchar3) * WIDTH * HEIGHT, cudaMemcpyHostToDevice);
    if (error != cudaSuccess) {
	std::cout << "Error in cudaMemcpy" << std::endl;
    }

    // Init output buffer to 0
    error = cudaMemset(d_rgba, 0, WIDTH*HEIGHT*sizeof(uchar4));
    if (error != cudaSuccess) {
        std::cout << "Error in cudaMemset" << std::endl;
    }

    //FUNCIO AMB UN SOL FOR
    /*dim3 block(64, 1, 1);
    dim3 grid(ceil(WIDTH*HEIGHT/(float)block.x), 1, 1);
    convertBGR2RGBA_1for<<<grid, block, 0, 0>>>(d_bgr, d_rgba, WIDTH, HEIGHT);*/

    //FUNCIO AMB DOS FORS
    /*dim3 block(8, 8, 1);
    dim3 grid(ceil(WIDTH/(float)block.x),ceil(HEIGHT/(float)block.y), 1);
    convertBGR2RGBA_2for<<<grid, block, 0, 0>>>(d_bgr, d_rgba, WIDTH, HEIGHT);*/


    //OPTIMITZACIONS DE MEMORIA
    dim3 block(128, 1, 1);
    dim3 grid(ceil(WIDTH*HEIGHT/(float)block.x),1, 1);
    convertBGR2RGBA_optBasic<<<grid, block, 0, 0>>>(d_bgr, d_rgba, WIDTH, HEIGHT);

    //OPTIMITZACIO DE MEMORIA 2
    /*dim3 block(512, 1, 1);
    dim3 grid(ceil(WIDTH*HEIGHT/(float)block.x),1, 1);
    convertBGR2RGBA_optBasic2<<<grid, block, 0, 0>>>(d_bgr, d_rgba, WIDTH, HEIGHT);*/

    //SHARED MEMORY
    /*dim3 block(1024, 1, 1);
    dim3 grid(ceil(WIDTH*HEIGHT/(float)block.x), 1, 1);
    convertBGR2RGBA_shared<<<grid, block>>>(d_bgr, d_rgba, WIDTH, HEIGHT);*/

    cudaDeviceSynchronize();

    // Copy data back from GPU to CPU
    error = cudaMemcpy(h_rgba, d_rgba, sizeof(uchar4) * WIDTH * HEIGHT, cudaMemcpyDeviceToHost);
    if (error != cudaSuccess) {
	std::cout << "Error in cudaMemcpy." << std::endl;
	std::cout << cudaGetErrorString(error) << std::endl;
    }

    // Check results
    bool ok = checkResults(h_rgba, h_bgr, WIDTH*HEIGHT);
    if (ok) {
        std::cout << "Executed!! Results OK." << std::endl;
    } else {
        std::cout << "Executed!! Results NOT OK." << std::endl;
    }

    // Free CPU pointers
    free(h_rgba);
    free(h_bgr);

    // Free cuda pointers
    error = cudaFree(d_bgr);
    if (error != cudaSuccess) {
	std::cout << "Error in cudaFree" << std::endl;
	std::cout << cudaGetErrorString(error) << std::endl;
    }
    error = cudaFree(d_rgba);
    if (error != cudaSuccess) {
	std::cout << "Error in cudaFree" << std::endl;
	std::cout << cudaGetErrorString(error) << std::endl;
    }

    // Clean GPU device
    error = cudaDeviceReset();
    if (error != cudaSuccess) {
	std::cout << "Error in cudaDeviceReset" << std::endl;
    }

    return 0;

}
