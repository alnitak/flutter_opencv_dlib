# Flutter OpenCV dlib

Realtime face detection and face recognition using OpenCV and dlib

## Getting Started (WIP)

https://user-images.githubusercontent.com/192827/224568828-988137d8-8f80-45a6-8721-0e922792e2c8.mp4

https://user-images.githubusercontent.com/192827/224568831-0734ca77-c203-4013-bc35-9b1f04d31010.mp4

This plugin is almost tested only on Linux and Android, any help is greatly appreciated!

On Android (not tested on iOS) the [camera](https://pub.dev/packages/camera) plugin is used to grab frames and send them to this plugin.

The camera plugin seems to have a different behavior running on the emulator or on a real device: the
viewfinder is rotated. For this purpose, in the example/lib/main.dart there is the [isRunninOnEmulator] const used to define the starting viewfinder rotation.

The the camera on Linux, uses frames provided by [cv::VideoCapture] OpenCV lib, it stores them into a OpenGL texture and send them back to a Texture() Flutter widget.
This should work on Windows and Mac, but it's not implemented. So the camera is not yet available on these OSes (any help would be greatly appreciated), but the plugin should work for example providing photos/images to it.

The c/c++ shared source code (for all platforms) is stored into ios/Classes/cpp for further iOS release.

In the ```assets``` dir are stored some models used here. They are available [here](https://github.com/davisking/dlib-models) and are
licensed under *[Creative Commons Zero v1.0 Universal](https://github.com/davisking/dlib-models/blob/master/LICENSE)*

For Linux within the example dir you should run lib/main_desktop.dart: 
```flutter run --release -t ./lib/main_desktop.dart```
which uses the OpenCV camera instead the camera plugin.

### WARNING

Running in debug mode the performances are very poor. In profile or release mode you'll get much more FPS

## Compiling libs

### Linux
install OpenCV and dlib with the package manager of your linux distribution.

### Android
Opencv v4.6.0 and dlib v19.24 are precompiled and stored into ```android/src/main```. 
If you want to update them, you can use the below instructions:

#### OpenCV
- download latest opencv-[x.y.z]-android-sdk.zip from [https://github.com/opencv/opencv/releases](https://github.com/opencv/opencv/releases)
- extract into BUILD_LIBS/buildOpenCV
- run copyLibs-android

#### dlib
- go to BUILD_LIBS/buildDlib
- run gitCloneDlib
- run buildDlib-android

### Windows
#### OpenCV
- download latest opencv-[x.y.z]-vc14_vc15.zip from [https://github.com/opencv/opencv/releases](https://github.com/opencv/opencv/releases)
- extract into BUILD_LIBS/buildOpenCV
- run buildOpenCV.bat
- 
#### dlib
- go to BUILD_LIBS/buildDlib
- run gitCloneDlib.bat
- run buildDlib-windows.bat


windows install reference: [learnopencv.com](https://learnopencv.com/install-dlib-on-windows/)
