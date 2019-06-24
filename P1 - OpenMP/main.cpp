#include <iostream>
#include <omp.h>

//4k
#define WIDTH 3840
#define HEIGHT 2160

using namespace std;
typedef unsigned char uchar;


struct _uchar3 {
    uchar x;
    uchar y;
    uchar z;
};

using uchar3 = _uchar3;

struct _uchar4 {
    uchar x;
    uchar y;
    uchar z;
    uchar w;
};

using uchar4 = _uchar4;

bool checkResults(uchar4* rgba, uchar3* bgr, int size) {

    bool correct = true;

    for (int i=0; i < size; ++i) {
        correct &= rgba[i].x == bgr[i].z;
        correct &= rgba[i].y == bgr[i].y;
        correct &= rgba[i].z == bgr[i].x;
        correct &= rgba[i].w == 255;
    }

    return correct;
}

//Funcio optimitzada
void convertBGR2RGBA(uchar3* bgr, uchar4* rgba, int width, int height) {

//Bloc que engloba els dos fors, paralelitzat
#pragma omp parallel
    {
#pragma omp for //Parelitzacio dels fors
    //For "girat"
    for (int y=0; y<height; ++y) {
    	for (int x=0; x<width; ++x) {
            //Regio critica per la correcte impresio del cout
        #pragma omp critical
            {
            cout << "Soc el fil numero " << omp_get_thread_num() << endl;
            }
            //Pos es calcula un cop
    		int pos = width * y + x;
            //Variables temporals
            uchar3 tempbgr = bgr[pos];
            uchar4 temprgba;
            
    		temprgba.x = tempbgr.z;
            temprgba.y = tempbgr.y;
            temprgba.z = tempbgr.x;
            temprgba.w = 255;
            
            rgba[pos] = temprgba;
        }
    }
	}
}

void permaConvertBGR2RGBA(uchar3* bgr, uchar4* rgba, int width, int height){
    for (int x=0; x<width; ++x) {
    	for (int y=0; y<height; ++y) {	
	    rgba[width * y + x].x = bgr[width * y + x].z;
	    rgba[width * y + x].y = bgr[width * y + x].y;
	    rgba[width * y + x].z = bgr[width * y + x].x;
	    rgba[width * y + x].w = 255;
        }
    }
}

int main() {

    uchar3 *h_bgr, *d_bgr;
    uchar4 *h_rgba, *d_rgba;

    int bar_widht = HEIGHT/3;

    // Alloc and generate BGR bars.
    h_bgr = (uchar3*)malloc(sizeof(uchar3)*WIDTH*HEIGHT);
    for (int i=0; i < WIDTH * HEIGHT; ++i) {
        if (i < bar_widht) { h_bgr[i] = { 255, 0, 0 }; }
        else if (i < bar_widht*2) { h_bgr[i] = { 0, 255, 0 }; }
        else { h_bgr[i] = { 0, 0, 255 }; }
    }

    // Alloc RGBA pointers
    h_rgba = (uchar4*)malloc(sizeof(uchar4)*WIDTH*HEIGHT);

    convertBGR2RGBA(h_bgr, h_rgba, WIDTH, HEIGHT);
    //permaConvertBGR2RGBA(h_bgr, h_rgba, WIDTH, HEIGHT);

    bool ok = checkResults(h_rgba, h_bgr, WIDTH*HEIGHT);

    if (ok) {
        cout << "Executed!! Results OK." << endl;
    } else {
        cout << "Executed!! Results NOT OK." << endl;
    }
    return 0;

}