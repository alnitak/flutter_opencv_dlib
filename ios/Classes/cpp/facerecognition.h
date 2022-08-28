#ifndef FACERECOGNITION_H
#define FACERECOGNITION_H

#include <opencv2/core/mat.hpp>

#include <dlib/dnn.h>
#include <dlib/clustering.h>
#include <dlib/string.h>

#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/image_processing.h>
#include <stdio.h>
#include <string>
#include "face_common.h"


struct ReconFace {
    std::string name;
    dlib::rectangle faceRect = dlib::rectangle(0,0);
    dlib::matrix<dlib::rgb_pixel> faceDlib;
    dlib::matrix<float,0,1> face_descriptor;
    bool detected = false;
    float length;
};

class FaceRecognition : public FaceCommon
{
public:
    FaceRecognition();

    void initFaceRecognition(std::string pathToShapePredictor,
                             std::string pathToFaceRecognition);

    void initFaceRecognition(char *sp, int64_t spSize,
                             char *fr, int64_t frSize);

    void adjustSource(cv::Mat &src);

    std::vector<ReconFace> detectFaces(cv::Mat &img);

    void train(std::string dir);

    bool addFace(ReconFace &facesRecon, std::string name, int jitterIterations);

    void compareFaces(std::vector<ReconFace> &reconFaces,
                         std::vector<ReconFace> &newFaces,
                         int32_t *faceCount);


private:
    // ----------------------------------------------------------------------------------------

    // The next bit of code defines a ResNet network.  It's basically copied
    // and pasted from the dnn_imagenet_ex.cpp example, except we replaced the loss
    // layer with loss_metric and made the network somewhat smaller.  Go read the introductory
    // dlib DNN examples to learn what all this stuff means.
    //
    // Also, the dnn_metric_learning_on_images_ex.cpp example shows how to train this network.
    // The dlib_face_recognition_resnet_model_v1 model used by this example was trained using
    // essentially the code shown in dnn_metric_learning_on_images_ex.cpp except the
    // mini-batches were made larger (35x15 instead of 5x5), the iterations without progress
    // was set to 10000, and the training dataset consisted of about 3 million images instead of
    // 55.  Also, the input layer was locked to images of size 150.
    template <template <int,template<typename>class,int,typename> class block, int N, template<typename>class BN, typename SUBNET>
    using residual = dlib::add_prev1<block<N,BN,1,dlib::tag1<SUBNET>>>;

    template <template <int,template<typename>class,int,typename> class block, int N, template<typename>class BN, typename SUBNET>
    using residual_down = dlib::add_prev2<dlib::avg_pool<2,2,2,2,dlib::skip1<dlib::tag2<block<N,BN,2,dlib::tag1<SUBNET>>>>>>;

    template <int N, template <typename> class BN, int stride, typename SUBNET>
    using block  = BN<dlib::con<N,3,3,1,1,dlib::relu<BN<dlib::con<N,3,3,stride,stride,SUBNET>>>>>;

    template <int N, typename SUBNET> using res       = dlib::relu<residual<block,N,dlib::bn_con,SUBNET>>;
    template <int N, typename SUBNET> using ares      = dlib::relu<residual<block,N,dlib::affine,SUBNET>>;
    template <int N, typename SUBNET> using res_down  = dlib::relu<residual_down<block,N,dlib::bn_con,SUBNET>>;
    template <int N, typename SUBNET> using ares_down = dlib::relu<residual_down<block,N,dlib::affine,SUBNET>>;


    template <typename SUBNET> using level0 = res_down<256,SUBNET>;
    template <typename SUBNET> using level1 = res<256,res<256,res_down<256,SUBNET>>>;
    template <typename SUBNET> using level2 = res<128,res<128,res_down<128,SUBNET>>>;
    template <typename SUBNET> using level3 = res<64,res<64,res<64,res_down<64,SUBNET>>>>;
    template <typename SUBNET> using level4 = res<32,res<32,res<32,SUBNET>>>;

    template <typename SUBNET> using alevel0 = ares_down<256,SUBNET>;
    template <typename SUBNET> using alevel1 = ares<256,ares<256,ares_down<256,SUBNET>>>;
    template <typename SUBNET> using alevel2 = ares<128,ares<128,ares_down<128,SUBNET>>>;
    template <typename SUBNET> using alevel3 = ares<64,ares<64,ares<64,ares_down<64,SUBNET>>>>;
    template <typename SUBNET> using alevel4 = ares<32,ares<32,ares<32,SUBNET>>>;


    // training network type
    using net_type = dlib::loss_metric<dlib::fc_no_bias<128,dlib::avg_pool_everything<
                                level0<
                                level1<
                                level2<
                                level3<
                                level4<
                                dlib::max_pool<3,3,2,2,dlib::relu<dlib::bn_con<dlib::con<32,7,7,2,2,
                                dlib::input_rgb_image
                                >>>>>>>>>>>>;

    // testing network type (replaced batch normalization with fixed affine transforms)
    using anet_type = dlib::loss_metric<dlib::fc_no_bias<128,dlib::avg_pool_everything<
                                alevel0<
                                alevel1<
                                alevel2<
                                alevel3<
                                alevel4<
                                dlib::max_pool<3,3,2,2,dlib::relu<dlib::affine<dlib::con<32,7,7,2,2,
                                dlib::input_rgb_image_sized<150>
                                >>>>>>>>>>>>;

    // ----------------------------------------------------------------------------------------

    std::vector<dlib::matrix<dlib::rgb_pixel>> jitter_image(
        const dlib::matrix<dlib::rgb_pixel>& img, int iterations
    );

    std::vector<std::vector<std::string>> load_objects_list (
        const std::string& dir
    );

    void load_mini_batch (
        const size_t num_people,     // how many different people to include
        const size_t samples_per_id, // how many images per person to select.
        dlib::rand& rnd,
        const std::vector<std::vector<std::string>>& objs,
        std::vector<dlib::matrix<dlib::rgb_pixel>>& images,
        std::vector<unsigned long>& labels
    );
    // ----------------------------------------------------------------------------------------

    std::mutex _mutex;
    dlib::frontal_face_detector detector;
    dlib::shape_predictor shapePredictor;
    std::vector<dlib::matrix<float,0,1>> face_descriptors;

public:
    anet_type net;

};

#endif // FACERECOGNITION_H
