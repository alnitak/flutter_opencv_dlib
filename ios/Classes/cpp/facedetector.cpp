#include "facedetector.h"
#include "common.h"
#include "face_common.h"

#include <opencv2/opencv.hpp>
#include <opencv2/core/mat.hpp>
#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/opencv.h>

size_t FixedQueue::m_size = 1;

FaceDetector::FaceDetector()
{
}

void FaceDetector::initShapePredictor(char *sp, int64_t size) {
    // We need a face detector.  We will use this to get bounding boxes for
    // each face in an image.
    detector = dlib::get_frontal_face_detector();

    std::vector<int8_t> data(sp, sp + size);

    // And we also need a shape_predictor.  This is the tool that will predict face
    // landmark positions given an image and face bounding box.  Here we are just
    // loading the model from the shape_predictor_68_face_landmarks.dat file you gave
    // as a command line argument.
    dlib::deserialize(data) >> shapePredictor;
}

void FaceDetector::initShapePredictor(std::string pathToShapePredictor) {
    // We need a face detector.  We will use this to get bounding boxes for
    // each face in an image.
    detector = dlib::get_frontal_face_detector();

    // And we also need a shape_predictor.  This is the tool that will predict face
    // landmark positions given an image and face bounding box.  Here we are just
    // loading the model from the shape_predictor_68_face_landmarks.dat file you gave
    // as a command line argument.
    dlib::deserialize(pathToShapePredictor) >> shapePredictor;
}




/*
 *
 */
void FaceDetector::draw_polyline(cv::Mat &img,
                   const std::vector<int32_t> points,
                   const int start, const int end,
                   bool isClosed)
{
    std::vector<cv::Point> p;
    for (int i = start*2; i <= end*2; i+=2)
    {
        p.push_back( cv::Point(points[i], points[i+1]) );
    }
    cv::polylines(img, p, isClosed, cv::Scalar(255,255,0), 1, 16);
}


/*
 *
 */
void FaceDetector::render_face(cv::Mat &img,
                               const std::vector<int32_t> points,
                               const int numberOfFacePoints)
{
    if (numberOfFacePoints == 68) {
        draw_polyline(img, points, 0,  16);          // Jaw line
        draw_polyline(img, points, 17, 21);          // Left eyebrow
        draw_polyline(img, points, 22, 26);          // Right eyebrow
        draw_polyline(img, points, 27, 30);          // Nose bridge
        draw_polyline(img, points, 30, 35, true);    // Lower nose
        draw_polyline(img, points, 36, 41, true);    // Left eye
        draw_polyline(img, points, 42, 47, true);    // Right Eye
        draw_polyline(img, points, 48, 59, true);    // Outer lip
        draw_polyline(img, points, 60, 67, true);    // Inner lip
    }
    if (numberOfFacePoints == 2) {
        std::vector<int32_t> p;
        p.push_back(points[0]);
        p.push_back(points[1]);
        p.push_back(points[2]);
        p.push_back(points[1]);
        p.push_back(points[2]);
        p.push_back(points[3]);
        p.push_back(points[0]);
        p.push_back(points[3]);
        draw_polyline(img, p, 0,  3, true);
    }
}

void FaceDetector::adjustSource(cv::Mat &src) {
    resampleMat(src, m_colorSpace, m_scaleFactor,
                 m_rotation, m_flip);
}

/* getOnlyRectangle = false
 * Return a linear array of [retFaceCount] 68 points (x,y)
 * 0,  16  Jaw line
 * 17, 21  Left eyebrow
 * 22, 26  Right eyebrow
 * 27, 30  Nose bridge
 * 30, 35  Lower nose
 * 36, 41  Left eye
 * 42, 47  Right Eye
 * 48, 59  Outer lip
 * 60, 67  Inner lip
 *
 * getOnlyRectangle = true (no need to call initDlib to load shape predictor)
 * Return a linear array of (x,y) serie of the rectangle of face area
 * 0-1  top-left (x,y)
 * 2-3  bottom-right (x,y)
 *
 * with [getOnlyRectangle]==true the returned array will define the
 * rectangle vertices
 *
 */
void FaceDetector::getFacePosePoints(cv::Mat &src,
                                     int32_t *retFaceCount) {
    std::vector<int32_t> retPoints;
    *retFaceCount = 0;

    adjustSource(src);

    dlib::cv_image<dlib::rgb_pixel> imgBig(src);

    std::vector<dlib::rectangle> faces = detector(imgBig);

//    shapes.size must be the same of faces.size
    if (shapes.size() != faces.size()) {
        for (size_t i=0; i< std::max(shapes.size(), faces.size()); i++) {
            if (faces.size() > shapes.size())
                shapes.push_back(Shapes());
            else {
                if (faces.size() != shapes.size())
                    shapes.pop_back();
            }
        }
    }

    // std::cout<<"NATIVE********" << "FACES found: "<< faces.size() <<
    //            " - SHAPES:" << shapes.size() <<
    //            std::endl;

    // Find the pose of each face.
    for (unsigned long i = 0; i < faces.size(); ++i)
    {
        // Landmark detection on small image
        if (!m_getOnlyRectangle)
            shapes[i].shapes   = shapePredictor(imgBig, faces[i]);

        shapes[i].rects    = faces[i];
        shapes[i].r        = cv::Rect(cv::Point(faces[i].left(),faces[i].top()),
                                  cv::Point(faces[i].right(), faces[i].bottom()));
        shapes[i].roi      = cv::Mat();
        shapes[i].skinMask = cv::Mat();

        // Custom Face Render
        if (shapes[i].shapes.num_parts() == 68) {
            retPoints.clear();
            for (int n = 0; n < 68; n++) {
                retPoints.push_back(shapes[i].shapes.part(n).x());
                retPoints.push_back(shapes[i].shapes.part(n).y());
            }

            shapes[i].antiShakeQueue.add(retPoints, 30);
            *retFaceCount += 1;
        }
        if (m_getOnlyRectangle)
        {
            retPoints.clear();
            retPoints.push_back((int32_t)faces[i].left());
            retPoints.push_back((int32_t)faces[i].top());
            retPoints.push_back((int32_t)faces[i].right());
            retPoints.push_back((int32_t)faces[i].bottom());

            shapes[i].antiShakeQueue.add(retPoints, 30);
            *retFaceCount += 1;
        }
    }

}

/*
 *
 */
void FaceDetector::drawFacePose(cv::Mat &src) {
    int32_t retFaceCount;
    getFacePosePoints(src, &retFaceCount);

    int nPoints = m_getOnlyRectangle ? 2 : 68;
    for (int i=0; i<retFaceCount; i++) {
        render_face(src, shapes[i].antiShakeQueue.average(), nPoints);
    }
}




















