#ifndef ANDROID_FACE_COMMON_H
#define ANDROID_FACE_COMMON_H

#include "common.h"

#include <opencv2/opencv.hpp>

class FaceCommon {
public:
    FaceCommon() : m_colorSpace(SRC_YUV) {}
    void setScaleFactor(double scale) {m_scaleFactor = scale;};
    void setInputColorSpace(ColorSpace colorSpace)
        {m_colorSpace = colorSpace;}

    /*
     *  0  Rotate 90 degrees clockwise
     *  1  Rotate 180 degrees clockwise
     *  2  Rotate 270 degrees clockwise
     *  other values doesn't rotate
     */
    void setRotation(int32_t rotation) {m_rotation = rotation;};

    /*  0  flipping around the x-axis
    *   1  flipping around y-axis
    *  -1 means flipping around both axes
    *   other values doesn't flip
    */
    void setFlip(int32_t flip) {m_flip = flip;};

    double m_scaleFactor = -1;
    ColorSpace m_colorSpace;
    int32_t m_rotation = -1;
    int32_t m_flip = -2;

};


#endif //ANDROID_FACE_COMMON_H
