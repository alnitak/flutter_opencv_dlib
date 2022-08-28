#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <iostream>
#include <istream>
#include <streambuf>
#include <dlib/opencv.h>
#ifndef __ANDROID__
#   include <dlib/gui_widgets.h>
#endif

#include "common.h"
#include "facedetector.h"
#include "facerecognition.h"

#ifdef __cplusplus
extern "C" {
#endif



FaceDetector *faceDetector = nullptr;
FaceRecognition *faceRecognition = nullptr;
std::mutex _face_mutex;

// -------------------------------------------------------------------------
/// face detector
FFI void initDetector(char *shapePredictor, int64_t size) {
    faceDetector = new FaceDetector();
    faceDetector->initShapePredictor(shapePredictor, size);
}

FFI void setDetectorAntiShakeSamples(int32_t antiShakeSamples) {
    if (faceDetector == nullptr) return;
    faceDetector->setAntiShakeSamples(antiShakeSamples);
}
FFI void setDetectorScaleFactor(double scale) {
    if (faceDetector == nullptr) return;
    faceDetector->setScaleFactor(scale);
}
FFI void setDetectorInputColorSpace(int32_t colorSpace) {
    if (faceDetector == nullptr) return;
    faceDetector->setInputColorSpace((ColorSpace)colorSpace);
}
FFI void setDetectorRotation(int32_t rotation) {
    if (faceDetector == nullptr) return;
    faceDetector->setRotation(rotation);
}
FFI void setDetectorFlip(int32_t flip) {
    if (faceDetector == nullptr) return;
    faceDetector->setFlip(flip);
}
FFI void setGetOnlyRectangle(bool onlyRect) {
    if (faceDetector == nullptr) return;
    faceDetector->setGetOnlyRectangle(onlyRect);
    faceDetector->shapes.clear();
}
FFI bool getGetOnlyRectangle() {
    if (faceDetector == nullptr) return false;
    return faceDetector->getGetOnlyRectangle();
}
//u_char *tmpRetImg;
FFI void free_pointer(u_char *ptr)
{
    // Free native memory in C which was allocated in C.
    LOGD("******NATIVE", "**************FREEING pointer addr: %p", ptr);
    free(ptr);
}

/*
 * returned u_char pointer must be deallocated in Dart
 */
FFI void getDetectorAdjustedSource(
        int32_t width,
        int32_t height,
        int32_t bytesPerPixel,
        u_char *imgBytes,
        u_char **retImg,
        int32_t *retImgLength) {
    if (faceDetector == nullptr) return;
    cv::Mat srcImg = cv::Mat(height, width, CV_8UC(bytesPerPixel), imgBytes);
    faceDetector->adjustSource(srcImg);
    *retImg = matToBmp(srcImg, retImgLength);
}

/*
 * returned u_char pointer must be deallocated in Dart
 */
FFI u_char *drawFacePose(int32_t width,
                         int32_t height,
                         int32_t bytesPerPixel,
                         u_char *imgBytes,
                         int32_t *retImgLength) {
    if (faceDetector == nullptr) return nullptr;
    u_char *retImg;
    cv::Mat srcImg = cv::Mat(height, width, CV_8UC(bytesPerPixel), imgBytes);
    faceDetector->drawFacePose(srcImg);
    retImg = matToBmp(srcImg, retImgLength);
    return retImg;
}

/*
 * returned int32_t pointer must be deallocated in Dart
 */
FFI int32_t *getFacePosePoints(int32_t width,
                  int32_t height,
                  int32_t bytesPerPixel,
                  u_char *imgBytes,
                  int32_t *faceCount) {

    if (faceDetector == nullptr) return nullptr;
    cv::Mat srcImg = cv::Mat(height, width, CV_8UC(bytesPerPixel), imgBytes);
    int32_t retFaceCount;
    *faceCount = 0;
    faceDetector->getFacePosePoints(
            srcImg,
            &retFaceCount);

    if (retFaceCount == 0) return nullptr;

    int nPoints = (faceDetector->getGetOnlyRectangle() ? 2 : 68);
    int32_t *ret = (int32_t *)malloc(retFaceCount * nPoints * 2 * sizeof (int32_t));
    for (int i=0; i<retFaceCount; ++i) {
        std::vector<int32_t> points =
                faceDetector->shapes[i].antiShakeQueue.average();
        for (int j=0; j<points.size(); ++j) {
            ret[i*nPoints*2 + j] = points[j];
        }
    }
    *faceCount = retFaceCount;
    return ret;
}



// -------------------------------------------------------------------------
/// face recognizer
std::vector<ReconFace> m_reconFaces;

FFI void initRecognition(char *shapePredictor, int64_t sizeSp,
                         char *faceRecon, int64_t sizeFr) {
    faceRecognition = new FaceRecognition();
    faceRecognition->initFaceRecognition(shapePredictor, sizeSp,
                                         faceRecon, sizeFr);
}

FFI void setRecognizerScaleFactor(double scale) {
    if (faceRecognition == nullptr) return;
    faceRecognition->setScaleFactor(scale);
}
FFI void setRecognizerInputColorSpace(int32_t colorSpace) {
    if (faceRecognition == nullptr) return;
    faceRecognition->setInputColorSpace((ColorSpace)colorSpace);
}
FFI void setRecognizerRotation(int32_t rotation) {
    if (faceRecognition == nullptr) return;
    faceRecognition->setRotation(rotation);
}
FFI void setRecognizerFlip(int32_t flip) {
    if (faceRecognition == nullptr) return;
    faceRecognition->setFlip(flip);
}

/*
 * returned u_char pointer must be deallocated in Dart
 */
FFI void getRecognizerAdjustedSource(
        int32_t width,
        int32_t height,
        int32_t bytesPerPixel,
        u_char *imgBytes,
        u_char **retImg,
        int32_t *retImgLength) {
    if (faceRecognition == nullptr) return;
    cv::Mat srcImg = cv::Mat(height, width, CV_8UC(bytesPerPixel), imgBytes);
    faceRecognition->adjustSource(srcImg);
    *retImg = matToBmp(srcImg, retImgLength);
}

struct ResultCompare {
    u_char *faceImg;
    int32_t imgSize;
    int32_t left;
    int32_t top;
    int32_t bottom;
    int32_t right;
    char *name;
    bool alreadyExists;
};
FFI void compareFaces(int32_t width,
                      int32_t height,
                      int32_t bytesPerPixel,
                      u_char *imgBytes,
                      struct ResultCompare **result,
                      int32_t *faceCount
                      ) {
    (*faceCount) = 0;
    if (faceRecognition == nullptr || width == 0 || height == 0) return;
    std::lock_guard<std::mutex> guard(_face_mutex);

    cv::Mat srcImg = cv::Mat(height, width, CV_8UC(bytesPerPixel), imgBytes);
    std::vector<ReconFace> currentChips;
    currentChips = faceRecognition->detectFaces(srcImg);
    if (currentChips.empty()) return;

    faceRecognition->compareFaces(m_reconFaces, currentChips, faceCount);
    
    // now [detected] field of the recognized face in [m_reconFaces] can be true
    int n = 0;
    for (int j = 0; j < m_reconFaces.size(); ++j) {
        if (m_reconFaces[j].detected && m_reconFaces[j].faceDlib.nc() == 150) {
            cv::Mat face = dlib::toMat(m_reconFaces[j].faceDlib);
            cv::putText(face,
                std::to_string(m_reconFaces[j].length),
                cv::Point(0, 150),
                cv::FONT_HERSHEY_DUPLEX,
                0.7,
                cv::Scalar(0,255,0),
                1,
                false);
            int32_t size;
            u_char *img = matToBmp(face, &size);
            if (size > 100 && img != nullptr) {

                result[n] = (struct ResultCompare *) malloc(sizeof(struct ResultCompare));
                result[n]->faceImg = img;
                result[n]->imgSize = size;
                result[n]->left = m_reconFaces[j].faceRect.left();
                result[n]->top = m_reconFaces[j].faceRect.top();
                result[n]->bottom = m_reconFaces[j].faceRect.bottom();
                result[n]->right = m_reconFaces[j].faceRect.right();
                result[n]->name = (char*)m_reconFaces[j].name.c_str();
                ++n;
            } else {
                if (img != nullptr) free(img);
                result[n]->faceImg = nullptr;
                result[n] = nullptr;
            }
        }
    }
    (*faceCount) = n;
}

/*
 * returned ResultCompare pointer must be deallocated in Dart
 */
FFI struct ResultCompare *addFace(int32_t width,
                 int32_t height,
                 int32_t bytesPerPixel,
                 char *name,
                 u_char *imgBytes
                 ) {
    if (faceRecognition == nullptr) return nullptr;
    std::lock_guard<std::mutex> guard(_face_mutex);
    cv::Mat srcImg = cv::Mat(height, width, CV_8UC(bytesPerPixel), imgBytes);
    std::vector<ReconFace> chips = faceRecognition->detectFaces(srcImg);

    // if more then 1 face is found return
    if (chips.size() != 1) return nullptr;
    int nFacesRecognized = 0;
    faceRecognition->compareFaces(m_reconFaces, chips, &nFacesRecognized);

    struct ResultCompare *result = nullptr;

    result = (ResultCompare*) malloc(sizeof(ResultCompare));
    if (result == nullptr) return nullptr;

    if (nFacesRecognized == 0) {
        if (faceRecognition->addFace(chips[0], name, 5)) {
            m_reconFaces.push_back(chips[0]);
        }
        cv::Mat chip = dlib::toMat(chips[0].faceDlib);
        int32_t size;
        result->faceImg = matToBmp(chip, &size);
        result->imgSize = size;
        if (size > 100 && result->faceImg != nullptr && chip.rows == 150) {
            result->left = chips[0].faceRect.left();
            result->top = chips[0].faceRect.top();
            result->right = chips[0].faceRect.right();
            result->bottom = chips[0].faceRect.bottom();
            result->name = name;
        } else {
            if (result->faceImg != nullptr) free(result->faceImg);
            free(result);
            result = nullptr;
        }
        result->alreadyExists = nFacesRecognized > 0;
    }

    return result;
}



#ifdef __cplusplus
}
#endif







