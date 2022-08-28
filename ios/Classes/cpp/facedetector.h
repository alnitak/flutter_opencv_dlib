#ifndef FACEDETECTOR_H
#define FACEDETECTOR_H

#include "common.h"
#include "fixed_queue.h"
#include "face_common.h"

#include <opencv2/core/mat.hpp>
#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/image_processing.h>
#include <stdio.h>


struct Shapes {
    dlib::full_object_detection shapes; // shapes acquired by dlib
    dlib::rectangle rects;              // rect faces acquired by dlib
    cv::Mat roi;                        // Mat to copy to captured frame (not used yet)
    cv::Mat skinMask;                   // skin Mat representing the face skin (not used yet)
    cv::Rect r;                         // enlarged rect to fit whole head (not used yet)
    FixedQueue antiShakeQueue;
    bool found;
};


class FaceDetector : public FaceCommon
{
public:
    FaceDetector();
    void initShapePredictor(std::string pathToShapePredictor);
    void initShapePredictor(char *sp, int64_t size);

    void setAntiShakeSamples(int32_t antiShakeSamples)
    {
        FixedQueue().setSize(antiShakeSamples);
    };

    void setGetOnlyRectangle(bool onlyRect) {
        m_getOnlyRectangle = onlyRect;
    }

    bool getGetOnlyRectangle() {
        return m_getOnlyRectangle;
    }

    void adjustSource(cv::Mat &src);

    void getFacePosePoints(cv::Mat &src,
                           int32_t *retFaceCount);

    void drawFacePose(cv::Mat &src);

    void render_face(cv::Mat &img,
                     const std::vector<int32_t> points,
                     const int numberOfFacePoints);

    std::vector<Shapes> shapes;

private:
    void draw_polyline(cv::Mat &img,
                       const std::vector<int32_t> points,
                       const int start, const int end,
                       bool isClosed = false);


    dlib::frontal_face_detector detector;
    dlib::shape_predictor shapePredictor;
    bool m_getOnlyRectangle = true;
};

#endif // FACEDETECTOR_H
