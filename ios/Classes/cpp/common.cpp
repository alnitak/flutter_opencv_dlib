#include "common.h"

#include <opencv2/opencv.hpp>

#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#include <cstdio>

std::mutex _mutex;



/*
 * Allocate and return BMP image bytes from [img]
 * The returned data must be freed
 */
u_char *matToBmp(cv::Mat &img, int32_t *retImgLength) {
    std::lock_guard<std::mutex> guard(_mutex);
    *retImgLength = 0;
    if (img.empty())
        return nullptr;
    u_char *retImg;
    std::vector<u_char> buf; // imencode() will resize this
    cv::Mat img2(img);
    cv::imencode(".bmp", img2, buf);
    retImg = (u_char *)malloc(buf.size() * sizeof(u_char));
    if (retImg == nullptr) return nullptr;
    std::copy(buf.begin(), buf.end(), retImg);

    *retImgLength = buf.size();
    return  retImg;
}

/*
 * Allocate and return RAW image bytes from [img]
 * The returned data must be freed
 */
u_char *matToRaw(cv::Mat &img, 
                int32_t *width, 
                int32_t *height, 
                int32_t *bytesPerPixel, 
                int32_t *retImgLength) {
    std::lock_guard<std::mutex> guard(_mutex);
    if (img.empty())
        return nullptr;
    int length = img.cols * img.rows * img.channels();
    *width = img.cols;
    *height = img.rows;
    *bytesPerPixel = img.channels();
    *retImgLength = length;
    u_char *retImg = (u_char *)malloc(length * sizeof(u_char));
    if (retImg == nullptr) {
        *width = 0;
        *height = 0;
        *bytesPerPixel = 0;
        *retImgLength = 0;
        return nullptr;
    }

    if (img.isContinuous()) {
         memcpy(retImg, img.data, length);
    } else {
        u_char *ptr = retImg;
        for (int i = 0; i < img.rows; ++i) {
            memcpy(ptr, img.ptr<uchar>(i), img.cols*img.channels());
            *ptr += img.cols*img.channels();
        }
    }

    return retImg;
}

/*
 * Adjust src based on its color space, rotation and flip values
 */
void resampleMat(cv::Mat &src, ColorSpace colorSpace, double scaleFactor,
                  int32_t rotation, int32_t flip) {
    std::lock_guard<std::mutex> guard(_mutex);
    switch (colorSpace) {
        case SRC_YUV:
            cv::cvtColor(src, src, cv::COLOR_YUV2RGB);
            break;
        case SRC_BGR:
            cv::cvtColor(src, src, cv::COLOR_BGR2RGB);
            break;
        case SRC_RGB:
            break;
        case SRC_RGBA:
            cv::cvtColor(src, src, cv::COLOR_RGBA2RGB);
            break;
        case SRC_GRAY:
            cv::cvtColor(src, src, cv::COLOR_GRAY2RGB);
            break;
    }

    if (scaleFactor > 0)
        cv::resize(src, src,  cv::Size(0, 0), scaleFactor, scaleFactor);
    if (rotation >= 0 && rotation <= 2)
        cv::rotate(src, src, rotation);
    if (flip >= -1 && flip <= 1)
        cv::flip(src, src, flip);
}