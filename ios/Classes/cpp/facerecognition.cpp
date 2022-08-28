#include "facerecognition.h"

#include <atomic>
#include <opencv2/opencv.hpp>
#include <opencv2/core/mat.hpp>
#include <dlib/image_io.h>
#include <dlib/opencv.h>
#include <dlib/dnn.h>
#include <dlib/misc_api.h>

using namespace dlib;
using namespace std;

// threshold under which a face is considered matched
#define LENGTH_THRESHOLD 0.6

FaceRecognition::FaceRecognition()
{
}

void FaceRecognition::initFaceRecognition(char *sp, int64_t spSize,
                                          char *fr, int64_t frSize) {
    // We need a face detector.  We will use this to get bounding boxes for
    // each face in an image.
    detector = get_frontal_face_detector();

    // And we also need a shape_predictor.  This is the tool that will predict face
    // landmark positions given an image and face bounding box.  Here we are just
    // loading the model from the shape_predictor_68_face_landmarks.dat file you gave
    // as a command line argument.
    std::vector<int8_t> data(sp, sp + spSize);
    deserialize(data) >> shapePredictor;
    data = std::vector<int8_t>(fr, fr + frSize);
    deserialize(data) >> net;
}

void FaceRecognition::initFaceRecognition(std::string pathToShapePredictor,
                                          std::string pathToFaceRecognition) {
    // We need a face detector. We will use this to get bounding boxes for
    // each face in an image.
    detector = get_frontal_face_detector();

    // And we also need a shape_predictor.  This is the tool that will predict face
    // landmark positions given an image and face bounding box.  Here we are just
    // loading the model from the shape_predictor_68_face_landmarks.dat file you gave
    // as a command line argument.
    deserialize(pathToShapePredictor) >> shapePredictor;
    deserialize(pathToFaceRecognition) >> net;
}


// ----------------------------------------------------------------------------------------

// We will need to create some functions for loading data.  This program will
// expect to be given a directory structured as follows:
//    top_level_directory/
//        person1/
//            image1.jpg
//            image2.jpg
//            image3.jpg
//        person2/
//            image4.jpg
//            image5.jpg
//            image6.jpg
//        person3/
//            image7.jpg
//            image8.jpg
//            image9.jpg
//
// The specific folder and image names don't matter, nor does the number of folders or
// images.  What does matter is that there is a top level folder, which contains
// subfolders, and each subfolder contains images of a single person.

// This function spiders the top level directory and obtains a list of all the
// image files.
std::vector<std::vector<string>> FaceRecognition::load_objects_list (
    const string& dir
)
{
    std::vector<std::vector<string>> objects;
    for (auto subdir : directory(dir).get_dirs())
    {
        std::vector<string> imgs;
        for (auto img : subdir.get_files())
            imgs.push_back(img);

        if (imgs.size() != 0)
            objects.push_back(imgs);
    }
    return objects;
}

// This function takes the output of load_objects_list() as input and randomly
// selects images for training.  It should also be pointed out that it's really
// important that each mini-batch contain multiple images of each person.  This
// is because the metric learning algorithm needs to consider pairs of images
// that should be close (i.e. images of the same person) as well as pairs of
// images that should be far apart (i.e. images of different people) during each
// training step.
void FaceRecognition::load_mini_batch (
    const size_t num_people,     // how many different people to include
    const size_t samples_per_id, // how many images per person to select.
    dlib::rand& rnd,
    const std::vector<std::vector<string>>& objs,
    std::vector<matrix<rgb_pixel>>& images,
    std::vector<unsigned long>& labels
)
{
    images.clear();
    labels.clear();
    DLIB_CASSERT(num_people <= objs.size(), "The dataset doesn't have that many people in it.");

    std::vector<bool> already_selected(objs.size(), false);
    matrix<rgb_pixel> image;
    for (size_t i = 0; i < num_people; ++i)
    {
        size_t id = rnd.get_random_32bit_number()%objs.size();
        // don't pick a person we already added to the mini-batch
        while(already_selected[id])
            id = rnd.get_random_32bit_number()%objs.size();
        already_selected[id] = true;

        for (size_t j = 0; j < samples_per_id; ++j)
        {
            const auto& obj = objs[id][rnd.get_random_32bit_number()%objs[id].size()];
            load_image(image, obj);
            images.push_back(std::move(image));
            labels.push_back(id);
        }
    }

    // You might want to do some data augmentation at this point.  Here we do some simple
    // color augmentation.
    for (auto&& crop : images)
    {
        disturb_colors(crop,rnd);
        // Jitter most crops
        if (rnd.get_random_double() > 0.1)
            crop = dlib::jitter_image(crop,rnd);
    }


    // All the images going into a mini-batch have to be the same size.  And really, all
    // the images in your entire training dataset should be the same size for what we are
    // doing to make the most sense.
    DLIB_CASSERT(images.size() > 0);
    for (auto&& img : images)
    {
        DLIB_CASSERT(img.nr() == images[0].nr() && img.nc() == images[0].nc(),
            "All the images in a single mini-batch must be the same size.");
    }
}

// ----------------------------------------------------------------------------------------


void FaceRecognition::train(string dir)
{
    auto objs = load_objects_list(dir);

    std::vector<matrix<rgb_pixel>> images;
    std::vector<unsigned long> labels;

    net_type net;

    dnn_trainer<net_type> trainer(net, sgd(0.0001, 0.9));
    trainer.set_learning_rate(0.1);
    trainer.be_verbose();
    trainer.set_synchronization_file("face_metric_sync", std::chrono::minutes(5));
    // I've set this to something really small to make the example terminate
    // sooner.  But when you really want to train a good model you should set
    // this to something like 10000 so training doesn't terminate too early.
    trainer.set_iterations_without_progress_threshold(300);

    // If you have a lot of data then it might not be reasonable to load it all
    // into RAM.  So you will need to be sure you are decompressing your images
    // and loading them fast enough to keep the GPU occupied.  I like to do this
    // using the following coding pattern: create a bunch of threads that dump
    // mini-batches into dlib::pipes.
    dlib::pipe<std::vector<matrix<rgb_pixel>>> qimages(4);
    dlib::pipe<std::vector<unsigned long>> qlabels(4);
    auto data_loader = [&qimages, &qlabels, &objs](time_t seed, FaceRecognition *me)
    {
        dlib::rand rnd(time(0)+seed);
        std::vector<matrix<rgb_pixel>> images;
        std::vector<unsigned long> labels;
        while(qimages.is_enabled())
        {
            try
            {
                me->load_mini_batch(5, 5, rnd, objs, images, labels);
                qimages.enqueue(images);
                qlabels.enqueue(labels);
            }
            catch(std::exception& e)
            {
                cout << "EXCEPTION IN LOADING DATA" << endl;
                cout << e.what() << endl;
            }
        }
    };
    // Run the data_loader from 5 threads.  You should set the number of threads
    // relative to the number of CPU cores you have.
    std::thread data_loader1([data_loader, this](){ data_loader(1, this); });
    std::thread data_loader2([data_loader, this](){ data_loader(2, this); });
    std::thread data_loader3([data_loader, this](){ data_loader(3, this); });
    std::thread data_loader4([data_loader, this](){ data_loader(4, this); });
    std::thread data_loader5([data_loader, this](){ data_loader(5, this); });


    // Here we do the training.  We keep passing mini-batches to the trainer until the
    // learning rate has dropped low enough.
    while(trainer.get_learning_rate() >= 1e-4)
    {
        qimages.dequeue(images);
        qlabels.dequeue(labels);
        trainer.train_one_step(images, labels);
    }

    // Wait for training threads to stop
    trainer.get_net();
    cout << "done training" << endl;

    // Save the network to disk
    net.clean();
    serialize("metric_network_renset.dat") << net;

    // stop all the data loading threads and wait for them to terminate.
    qimages.disable();
    qlabels.disable();
    data_loader1.join();
    data_loader2.join();
    data_loader3.join();
    data_loader4.join();
    data_loader5.join();
}

void FaceRecognition::adjustSource(cv::Mat &src) {
    resampleMat(src, m_colorSpace, m_scaleFactor,
                m_rotation, m_flip);
}

// ----------------------------------------------------------------------------------------
// Capture faces in [img] and return them at 150x150px RGB inside ReconFace struct
// ----------------------------------------------------------------------------------------
std::vector<ReconFace> FaceRecognition::detectFaces(cv::Mat &img)
{
    adjustSource(img);

    cv_image<rgb_pixel> frame(img);
    std::vector<ReconFace> reconFaces;
    for (auto face : detector(frame))
    {
        ReconFace reconFace;
        auto shape = shapePredictor(frame, face);
        matrix<rgb_pixel> face_chip;
        extract_image_chip(
                frame,
                get_face_chip_details(shape, 150, 0.25),
                face_chip);

        reconFace.faceDlib = move(face_chip);
        reconFace.faceRect = shape.get_rect();

        reconFaces.push_back(reconFace);
    }

    return reconFaces;
}


// ----------------------------------------------------------------------------------------
// add faces to face descriptor
// ----------------------------------------------------------------------------------------
bool FaceRecognition::addFace(ReconFace &facesRecon,
                              std::string name,
                              int32_t jitterIterations)
{
    if (facesRecon.faceDlib.nc() == 0 ||
            facesRecon.faceDlib.nr() == 0 ||
            facesRecon.faceRect.is_empty()) return false;

    std::lock_guard<std::mutex> guard(_mutex);

    std::cout << "********************** FACE ADDING1" << std::endl;
    // This call asks the DNN to convert each face image in faces into a 128D vector.
    // In this 128D vector space, images from the same person will be close to each other
    // but vectors from different people will be far apart.  So we can use these vectors to
    // identify if a pair of images are from the same person or from different people.
    try {
        facesRecon.face_descriptor =
                        mean(
                            mat(
                                 net(
                                     jitter_image(facesRecon.faceDlib, jitterIterations)
                            )));

        facesRecon.name = name;
    }
    catch (std::exception& e)
    {
        cout << e.what() << endl;
        return false;
    }
    return true;
}

void getLossMetric(FaceRecognition *me, ReconFace &face) {
    std::cout << "********************** FACE COMPARE3-a\n";
    face.face_descriptor = me->net(face.faceDlib);
    std::cout << "********************** FACE COMPARE3-b\n";
}

// return the number of faces found and store them into [newFaces]
// set [reconFaces.detected] to true if face is found
void FaceRecognition::compareFaces(std::vector<ReconFace> &reconFaces,
                                   std::vector<ReconFace> &newFaces,
                                   int32_t *faceCount)
{
    if (reconFaces.size() == 0) return;
    std::lock_guard<std::mutex> guard(_mutex);

    for (int j = 0; j < reconFaces.size(); ++j)
        reconFaces[j].detected = false;
    if (newFaces.size() == 0) return;

    *faceCount = 0;
    try {
        // build the descriptor of all faces found
        std::vector<std::thread> threads;
        for (int i=0; i<newFaces.size(); ++i) {
            threads.emplace_back(
                std::thread([this, i, &newFaces] (anet_type net) {
                    newFaces[i].face_descriptor = net(newFaces[i].faceDlib);
                }, net)
            );
        }

        std::for_each(threads.begin(), threads.end(), [](std::thread &t) 
        {
            if (t.joinable()) t.join();
        });

        for (int j = 0; j < reconFaces.size(); ++j)
        {
            for (int i = 0; i < newFaces.size(); ++i)
            {
                // Faces are connected in the graph if they are close enough.  Here we check if
                // the distance between two face descriptors is less than 0.6, which is the
                // decision threshold the network was trained to use.  Although you can
                // certainly use any other threshold you find useful.
                float l = length(newFaces[i].face_descriptor-reconFaces[j].face_descriptor);

                if (l < LENGTH_THRESHOLD){
                    // FACE FOUND!!!
                    (*faceCount)++;
                    reconFaces[j].faceDlib = newFaces[i].faceDlib;
                    reconFaces[j].detected = true;
                    reconFaces[j].faceRect = newFaces[i].faceRect;
                    reconFaces[j].length = l;
                    break;
                }
            }
        }


//        std::vector<unsigned long> labels;
//        const auto num_clusters = chinese_whispers(edges, labels);
//        // This will correctly indicate that there are 4 people in the image.
//        std::cout << "number of people found in the image: "<< num_clusters << std::endl;



//        // Now let's display the face clustering results on the screen.  You will see that it
//        // correctly grouped all the faces.
//        for (size_t cluster_id = 0; cluster_id < num_clusters; ++cluster_id)
//        {
//            std::vector<matrix<rgb_pixel>> temp;
//            for (size_t j = 0; j < labels.size(); ++j)
//            {
//                if (cluster_id == labels[j]) {
//                    temp.push_back(faces[cluster_id]);
//                    std::cout << "**************** CHINESE WHISPER: "<<j<< std::endl;
//                }
//            }
//            win_clusters[cluster_id].set_title("face cluster " + cast_to_string(cluster_id));
//            win_clusters[cluster_id].set_image(tile_images(temp));
//            win_clusters[cluster_id].set_pos(20, 600+cluster_id*200);
//        }



//        // Finally, let's print one of the face descriptors to the screen.
//        std::cout << "face descriptor for one face: " << trans(reconFaces[0].face_descriptor) << std::endl;

//        // It should also be noted that face recognition accuracy can be improved if jittering
//        // is used when creating face descriptors.  In particular, to get 99.38% on the LFW
//        // benchmark you need to use the jitter_image() routine to compute the descriptors,
//        // like so:
//        matrix<float,0,1> face_descriptor = mean(mat(net(jitter_image(faces[0]))));
//        std::cout << "jittered face descriptor for one face: " << trans(face_descriptor) << std::endl;
//        // If you use the model without jittering, as we did when clustering the bald guys, it
//        // gets an accuracy of 99.13% on the LFW benchmark.  So jittering makes the whole
//        // procedure a little more accurate but makes face descriptor calculation slower.

    }
    catch (std::exception& e)
    {
        std::cout << "Native FaceRecognition::compareFaces()\n";
        cout << e.what() << endl;
    }
}




std::vector<matrix<rgb_pixel>> FaceRecognition::jitter_image(
    const matrix<rgb_pixel>& img, int32_t iterations)
{
    // All this function does is make 100 copies of img, all slightly jittered by being
    // zoomed, rotated, and translated a little bit differently. They are also randomly
    // mirrored left to right.
    thread_local dlib::rand rnd;

    std::vector<matrix<rgb_pixel>> crops;
    for (int i = 0; i < iterations; ++i)
        crops.push_back(dlib::jitter_image(img,rnd));

    return crops;
}

