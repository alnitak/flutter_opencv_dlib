import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_opencv_dlib/flutter_opencv_dlib.dart';
import 'package:flutter_opencv_dlib/src/face_points.dart';

import 'camera_stack.dart';
import 'points_painter.dart';

bool isRunninOnEmulator = true;

late List<CameraDescription> cameras;
// * on emulator the camera is rotated by 90°

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  for (int i = 0; i < cameras.length; i++) {
    print('AVAILABLE CAMERAS: $i  '
        'name: ${cameras[i].name}   '
        'lensDirection: ${cameras[i].lensDirection}   '
        'sensorOrientation: ${cameras[i].sensorOrientation}');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  late CameraController controller;
  CameraImage? _cameraImage;
  late int rotate;
  late int flip;
  late int cameraId;
  late bool startGrab;
  late bool isComputingFrame;
  late ValueNotifier<bool> _isDetectMode;
  late ValueNotifier<FacePoints> _points;
  late ValueNotifier<Uint8List> _adjustedImg;
  late ValueNotifier<Uint8List> _faceImage;
  late ValueNotifier<String> _textCamera;
  late ValueNotifier<String> _textDlib;
  late ValueNotifier<int> _antiShake;
  late bool detectorInitialized;
  late bool recognizerInitialized;
  late double fpsCamera;
  late double fpsDlib;
  late bool tryToAddFace;
  Timer? timer;
  int faceID = 1;

  late ValueNotifier<bool> _getFacePoints;

  @override
  void initState() {
    super.initState();

    rotate = -1;
    flip = 2;
    cameraId = 0;
    startGrab = false;
    isComputingFrame = false;
    detectorInitialized = false;
    recognizerInitialized = false;
    fpsCamera = 0;
    fpsDlib = 0;
    tryToAddFace = false;
    _isDetectMode = ValueNotifier(true);
    _points = ValueNotifier(FacePoints(0, 0, Int32List(0), []));
    _adjustedImg = ValueNotifier(Uint8List(0));
    _faceImage = ValueNotifier(Uint8List(0));
    _textCamera = ValueNotifier('');
    _textDlib = ValueNotifier('');
    _antiShake = ValueNotifier(0);

    _getFacePoints = ValueNotifier(true);

    controller = CameraController(
      cameras[cameraId],
      ResolutionPreset.low,
      enableAudio: false,
      // imageFormatGroup: ImageFormatGroup.yuv420,
    );

    RecognizerInterface().initRecognizer().then((b) {
      recognizerInitialized = b;
      RecognizerInterface().setInputColorSpace(ColorSpace.SRC_GRAY);

      rotate = cameras[cameraId].sensorOrientation == 90 && isRunninOnEmulator
          ? -1
          : 0;
      RecognizerInterface().setRotation(rotate);

      if (mounted) {
        setState(() {});
      }
    });

    DetectorInterface().initDetector().then((b) {
      detectorInitialized = b;
      DetectorInterface().setInputColorSpace(ColorSpace.SRC_GRAY);

      rotate = cameras[cameraId].sensorOrientation == 90 && isRunninOnEmulator
          ? -1
          : 0;
      DetectorInterface().setRotation(rotate);

      if (mounted) {
        setState(() {});
      }
    });

    controller.initialize().then((_) async {
      print('AS: ${controller.value.aspectRatio}'
          '   SIZE: ${controller.value.previewSize}'
          '   ORIENTATION: ${controller.value.deviceOrientation}'
          '   RES PRESET: ${controller.resolutionPreset}'
          '   IMG FMT GROUP: ${controller.imageFormatGroup}'
          '   CAMERA SENSOR: ${cameras[cameraId].sensorOrientation}');
      if (mounted) {
        setState(() {});
      }
    });

    //////////////////////////////////////////////////
    /// USE STREAMBUILDER?
    // * called when new points are available
    DetectorInterface().streamPointsController.stream.listen((pointsMap) {
      _points.value = pointsMap;
      fpsDlib++;
    });

    // * called when a face is added
    RecognizerInterface().streamAddFaceController.stream.listen((addedFaceImg) {
      fpsDlib++;
      if (addedFaceImg.face.isNotEmpty) {
        _faceImage.value = addedFaceImg.face;
        if (!addedFaceImg.alreadyExists) {
          faceID++;
        }
      }
      if (messengerKey.currentState != null) {
        String text = addedFaceImg.alreadyExists
            ? 'FACE ALREADY EXISTS'
            : 'FACE ADDED ${addedFaceImg.name}';
        messengerKey.currentState!.showSnackBar(SnackBar(content: Text(text)));
      }
    });

    // * called when a face(s) is recognized
    RecognizerInterface().streamCompareFaceController.stream.listen((faces) {
      fpsDlib++;
      if (faces.isNotEmpty && faces[0].face.isNotEmpty) {
        _faceImage.value = faces[0].face;
        List<int> points = [];
        for (var element in faces) {
          points.addAll(element.rectPoints);
        }

        _points.value = FacePoints(
          faces.length,
          2,
          points,
          List.generate(faces.length, (index) => faces[index].name),
        );
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    timer?.cancel();
    super.dispose();
  }

  _computeDetectorPoints(CameraImage image) {
    fpsCamera++;
    if (isComputingFrame) return;
    isComputingFrame = true;
    // * send only Y plane of YUV frame
    _cameraImage = image;

    if (_cameraImage?.planes[0] != null) {
      DetectorInterface()
          .getFacePosePoints(
        controller.value.previewSize?.width.toInt() ?? 0,
        controller.value.previewSize?.height.toInt() ?? 0,
        _cameraImage!.planes[0].bytesPerPixel,
        _cameraImage!.planes[0].bytes,
      )
          .then((_) {
        isComputingFrame = false;
      });
    } else {
      isComputingFrame = false;
      print('***********getFacePosePoints3');
    }
  }

  _computeRecognize(CameraImage image) {
    fpsCamera++;

    if (isComputingFrame) return;
    isComputingFrame = true;
    _cameraImage = image;

    if (_cameraImage?.planes[0] != null) {
      if (tryToAddFace) {
        tryToAddFace = false;
        RecognizerInterface()
            .addFace(
          controller.value.previewSize?.width.toInt() ?? 0,
          controller.value.previewSize?.height.toInt() ?? 0,
          _cameraImage!.planes[0].bytesPerPixel ?? 1,
          'face $faceID',
          _cameraImage!.planes[0].bytes,
        )
            .then((_) {
          isComputingFrame = false;
        });
      } else {
        RecognizerInterface()
            .compareFace(
          controller.value.previewSize?.width.toInt() ?? 0,
          controller.value.previewSize?.height.toInt() ?? 0,
          _cameraImage!.planes[0].bytesPerPixel ?? 1,
          _cameraImage!.planes[0].bytes,
        )
            .then((_) {
          isComputingFrame = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        backgroundColor: const Color(0xFF2f2f2f),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // * Camera
            if (!controller.value.isInitialized)
              const CircularProgressIndicator.adaptive()
            else
              ValueListenableBuilder<FacePoints>(
                  valueListenable: _points,
                  builder: (_, points, __) {
                    return CameraStack(
                        cameraDescription: cameras[cameraId],
                        controller: controller,
                        isRunninOnEmulator: isRunninOnEmulator,
                        width: 200,
                        points: points);
                  }),

            // * FPS camera
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ValueListenableBuilder<String>(
                    valueListenable: _textCamera,
                    builder: (_, text, __) {
                      return Text('camera FPS: $text');
                    }),

                const SizedBox(width: 30),

                // * FPS DLib
                ValueListenableBuilder<String>(
                    valueListenable: _textDlib,
                    builder: (_, text, __) {
                      return Text('FPS DLib: $text');
                    }),
              ],
            ),

            // * Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // * start / stop detect
                if (!detectorInitialized || !recognizerInitialized)
                  const CircularProgressIndicator.adaptive()
                else
                  OutlinedButton(
                    child: Text(startGrab ? 'Stop' : 'Start'),
                    onPressed: () {
                      if (startGrab) {
                        startGrab = false;
                        controller.stopImageStream();
                        timer?.cancel();
                        setState(() {});
                      } else {
                        startGrab = true;
                        timer?.cancel();

                        /// Timer to modify fps text and debug image
                        timer = Timer.periodic(
                            const Duration(milliseconds: 1000), (timer) {
                          _textCamera.value = fpsCamera.toString();
                          _textDlib.value = fpsDlib.toString();
                          if (_isDetectMode.value && _cameraImage != null) {
                            DetectorInterface()
                                .getAdjustedSource(
                                    _cameraImage!.width,
                                    _cameraImage!.height,
                                    _cameraImage!.planes[0].bytesPerPixel ?? 1,
                                    _cameraImage!.planes[0].bytes)
                                .then((value) => _adjustedImg.value = value);
                          } else {
                            RecognizerInterface()
                                .getAdjustedSource(
                                    _cameraImage!.width,
                                    _cameraImage!.height,
                                    _cameraImage!.planes[0].bytesPerPixel ?? 1,
                                    _cameraImage!.planes[0].bytes)
                                .then((value) => _adjustedImg.value = value);
                          }
                          fpsCamera = fpsDlib = 0;
                        });

                        controller.startImageStream(_isDetectMode.value
                            ? _computeDetectorPoints
                            : _computeRecognize);
                        setState(() {});
                      }
                    },
                  ),

                OutlinedButton.icon(
                  label: const Text('cam'),
                  icon: const Icon(Icons.rotate_90_degrees_ccw),
                  onPressed: () async {
                    setState(() {
                      isRunninOnEmulator = !isRunninOnEmulator;
                    });
                  },
                ),

                // * front / rear camera
                if (!controller.value.isInitialized)
                  const CircularProgressIndicator.adaptive()
                else
                  OutlinedButton.icon(
                    label: const Text('cam'),
                    icon: cameraId == 0
                        ? const Icon(Icons.camera_rear_outlined)
                        : const Icon(Icons.camera_front_outlined),
                    onPressed: () async {
                      cameraId++;
                      startGrab = false;
                      if (cameraId > 1) cameraId = 0;
                      await controller.dispose();
                      controller = CameraController(
                        cameras[cameraId],
                        ResolutionPreset.low,
                        enableAudio: false,
                        // * imageFormatGroup: ImageFormatGroup.yuv420,
                      );
                      controller.initialize().then((_) async {
                        print('AS: ${controller.value.aspectRatio}'
                            '   SIZE: ${controller.value.previewSize}'
                            '   ORIENTATION: ${controller.value.deviceOrientation}'
                            '   RES PRESET: ${controller.resolutionPreset}'
                            '   IMG FMT GROUP: ${controller.imageFormatGroup}'
                            '   CAMERA SENSOR: ${cameras[cameraId].sensorOrientation}');
                        if (mounted) {
                          setState(() {});
                        }
                      });
                    },
                  ),
              ],
            ),

            // * detector / recognizer buttons
            ValueListenableBuilder<bool>(
                valueListenable: _isDetectMode,
                builder: (_, isDetectMode, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // * detector button
                      OutlinedButton(
                        style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                isDetectMode
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.transparent)),
                        onPressed: () async {
                          if (controller.value.isStreamingImages) {
                            await controller.stopImageStream();
                          }
                          _isDetectMode.value = true;
                          await controller
                              .startImageStream(_computeDetectorPoints);
                          setState(() {});
                        },
                        child: const Text('detector'),
                      ),

                      // * recognizer button
                      OutlinedButton(
                        style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                !isDetectMode
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.transparent)),
                        onPressed: () async {
                          if (controller.value.isStreamingImages) {
                            await controller.stopImageStream();
                          }
                          _isDetectMode.value = false;
                          await controller.startImageStream(_computeRecognize);
                          setState(() {});
                        },
                        child: const Text('recognizer'),
                      ),
                    ],
                  );
                }),

            // * anti shake
            if (_isDetectMode.value)
              ValueListenableBuilder<int>(
                  valueListenable: _antiShake,
                  builder: (_, antiShake, __) {
                    return Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text('anti shake ${_antiShake.value}'),
                        Expanded(
                          child: Slider.adaptive(
                            min: 0,
                            max: 10,
                            divisions: 11,
                            value: antiShake.toDouble(),
                            onChanged: (v) {
                              _antiShake.value = v.toInt();
                              DetectorInterface()
                                  .setAntiShake(_antiShake.value);
                            },
                          ),
                        ),
                      ],
                    );
                  }),

            ValueListenableBuilder<bool>(
                valueListenable: _isDetectMode,
                builder: (_, isDetectMode, __) {
                  return Row(
                    children: [
                      // * image which DLib will process (for debug purpose)
                      Column(
                        children: [
                          const Text('what DLib\nwill process'),
                          ValueListenableBuilder<Uint8List>(
                              valueListenable: _adjustedImg,
                              builder: (_, adjustedImg, __) {
                                if (_cameraImage == null) {
                                  return Container();
                                }
                                return SizedBox(
                                  width: 130,
                                  height: 130 / controller.value.aspectRatio,
                                  child: Image.memory(
                                    adjustedImg,
                                    width: _cameraImage!.width.toDouble(),
                                    height: _cameraImage!.height.toDouble(),
                                    gaplessPlayback: true,
                                  ),
                                );
                              }),
                        ],
                      ),

                      // * Detect mode: Landmark points / rectangle
                      if (isDetectMode)
                        ValueListenableBuilder<bool>(
                            valueListenable: _getFacePoints,
                            builder: (_, getFacePoints, __) {
                              return OutlinedButton.icon(
                                label: Text(
                                    getFacePoints ? 'landmaks' : 'rectangle'),
                                icon: Icon(getFacePoints
                                    ? Icons.face
                                    : Icons.crop_square),
                                onPressed: () {
                                  _getFacePoints.value = !_getFacePoints.value;
                                  DetectorInterface().setGetOnlyRectangle(
                                      _getFacePoints.value);
                                },
                              );
                            }),

                      // * add face
                      if (!isDetectMode && recognizerInitialized && startGrab)
                        OutlinedButton.icon(
                          label: const Text('add face'),
                          icon: const Icon(Icons.face),
                          onPressed: () {
                            tryToAddFace = true;
                          },
                        ),

                      // * face image added
                      if (!isDetectMode)
                        ValueListenableBuilder<Uint8List>(
                            valueListenable: _faceImage,
                            builder: (_, recognizedFaceImage, __) {
                              if (recognizedFaceImage.isEmpty)
                                return Container();
                              return Image.memory(
                                recognizedFaceImage,
                                width: 100,
                                gaplessPlayback: true,
                              );
                            }),
                    ],
                  );
                }),

            Row(
              children: [
                // * rotate frame to pass to dlib
                OutlinedButton.icon(
                  label: const Text('rotate'),
                  icon: const Icon(Icons.rotate_left),
                  onPressed: () {
                    rotate--;
                    if (rotate < -1) rotate = 2;
                    if (_isDetectMode.value) {
                      DetectorInterface().setRotation(rotate);
                    } else {
                      RecognizerInterface().setRotation(rotate);
                    }
                  },
                ),

                // * flip frame to pass to dlib
                OutlinedButton.icon(
                  label: const Text('flip'),
                  icon: const Icon(Icons.flip_outlined),
                  onPressed: () {
                    flip--;
                    if (flip < -2) flip = 1;
                    if (_isDetectMode.value) {
                      DetectorInterface().setFlip(flip);
                    } else {
                      RecognizerInterface().setFlip(flip);
                    }
                  },
                ),
              ],
            ),

            // * points
            ValueListenableBuilder<FacePoints>(
                valueListenable: _points,
                builder: (_, points, __) {
                  if (points.nFaces == 0) {
                    return Container();
                  }
                  double w = controller.value.previewSize?.width ?? 320;
                  double h = controller.value.previewSize?.height ?? 240;
                  bool isSwapped = false;
                  if ((cameras[cameraId].sensorOrientation == 90 ||
                          cameras[cameraId].sensorOrientation == 270) &&
                      isRunninOnEmulator) {
                    isSwapped = true;
                  }

                  return SizedBox(
                    width: 150,
                    child: FittedBox(
                      child: CustomPaint(
                        size: Size(isSwapped ? w : h, isSwapped ? h : w),
                        painter: PointsPainter(
                          pointsMap: points,
                          backgroundColor: Colors.black,
                        ),
                      ),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}
