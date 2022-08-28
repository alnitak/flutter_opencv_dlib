#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <opencv2/core/mat.hpp>
#include <opencv2/imgcodecs.hpp>

enum ColorSpace {
    SRC_RGB = 0,
    SRC_BGR,
    SRC_RGBA,
    SRC_YUV,
    SRC_GRAY
};

#ifdef __ANDROID__
#   include <android/log.h>
#   define  LOGD(TAG, ...)  __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)
#elif __linux__
//#include <QDebug>
#   include <cstdio>
#   define  LOGD(TAG, ...) {std::cout<<TAG;std::cout<<" - ";std::cout<<__VA_ARGS__;std::cout<<std::endl;};
#endif

#ifdef _WIN32
#   define FFI extern "C" __declspec(dllexport)
#   pragma warning ( disable : 4310 )
#else
#   define FFI extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Allocate and return BMP image bytes from [img]
 * The returned data must be freed
*/
FFI u_char *matToBmp(cv::Mat &img, int32_t *retImgLength);

FFI u_char *matToRaw(cv::Mat &img, 
                int32_t *width, 
                int32_t *height, 
                int32_t *bytesPerPixel, 
                int32_t *retImgLength);

FFI void resampleMat(cv::Mat &src, ColorSpace colorSpace, double scaleFactor,
                  int32_t rotation, int32_t flip);


#ifdef __cplusplus
}
#endif

#endif // COMMON_H
