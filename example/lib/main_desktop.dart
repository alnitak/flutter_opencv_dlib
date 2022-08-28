import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_opencv_dlib/flutter_opencv_dlib.dart';

import 'points_painter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  late bool canBuild;
  late int textureID;
  late int width;
  late int height;
  late double fpsDlib;
  late int faceID;
  late bool tryToAddFace;
  late bool isComputingFrame;
  late bool startGrab;
  late ValueNotifier<String> _textDlib;
  late ValueNotifier<Uint8List> _adjustedImg;
  late ValueNotifier<List<Uint8List>> _faceImage;
  late ValueNotifier<bool> _isDetectMode;
  late ValueNotifier<int> _antiShake;
  late ValueNotifier<FacePoints> _points;
  late ValueNotifier<bool> _getFacePoints;
  late bool detectorInitialized;
  late bool recognizerInitialized;
  Timer? timer;
  late Ticker ticker;

  @override
  void initState() {
    super.initState();

    canBuild = false;
    startGrab = false;
    width = 640;
    height = 360;
    fpsDlib = 0;
    faceID = 1;
    tryToAddFace = false;
    isComputingFrame = false;
    detectorInitialized = false;
    recognizerInitialized = false;
    _textDlib = ValueNotifier('');
    _adjustedImg = ValueNotifier<Uint8List>(Uint8List(0));
    _faceImage = ValueNotifier([]);
    _isDetectMode = ValueNotifier(true);
    _antiShake = ValueNotifier(0);
    _points = ValueNotifier(FacePoints(0, 0, Int32List(0), []));
    _getFacePoints = ValueNotifier(true);

    ticker = Ticker(_computeDetectorPoints);
    _init();

    // * start camera
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Future.delayed(const Duration(milliseconds: 500), () {
        OpenCVCamera().openOpenCVCamera();
        OpenCVCamera().startOpenCVCamera();
      });
    });
  }

  _init() async {
    textureID = await OpenCVCamera().registerTexture(width, height) ?? -1;

    // * initialize Recognizer
    RecognizerInterface().initRecognizer().then((b) {
      recognizerInitialized = b;
      RecognizerInterface().setInputColorSpace(ColorSpace.SRC_RGB);
    });

    // * initialize Detector
    DetectorInterface().initDetector().then((b) {
      detectorInitialized = b;
      DetectorInterface().setInputColorSpace(ColorSpace.SRC_RGB);
    });

    // * called when new points are available
    DetectorInterface().streamPointsController.stream.listen((pointsMap) {
      fpsDlib++;
      _points.value = pointsMap;
    });

    // * called when a face is added
    RecognizerInterface().streamAddFaceController.stream.listen((addedFaceImg) {
      if (addedFaceImg.face.isNotEmpty) {
        _faceImage.value = [addedFaceImg.face];
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
      print('**DART1 streamCompareFaceController ${faces.length}');
      fpsDlib++;
      if (faces.isNotEmpty && faces[0].face.isNotEmpty) {
        _faceImage.value = List.generate(faces.length, (index) => 
            faces[index].face);
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

    /// time to build ui
    setState(() {
      canBuild = true;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    ticker.dispose();
    super.dispose();
  }

  _computeDetectorPoints(Duration timestamp) {
    if (isComputingFrame) return;
    isComputingFrame = true;
    CameraFrame frame = OpenCVCamera().getRAWOpenCVCameraFrame();

    if (frame.bytes.isNotEmpty) {
      DetectorInterface()
          .getFacePosePoints(
        frame.width,
        frame.height,
        frame.bytesPerPixel,
        frame.bytes,
      )
          .then((_) {
        isComputingFrame = false;
      });
    } else {
      isComputingFrame = false;
    }
  }

  _computeRecognize(Duration timestamp) {
    if (isComputingFrame) return;
    isComputingFrame = true;
    CameraFrame frame = OpenCVCamera().getRAWOpenCVCameraFrame();

    if (frame.bytes.isNotEmpty) {
      if (tryToAddFace) {
        tryToAddFace = false;
        RecognizerInterface()
            .addFace(
          frame.width,
          frame.height,
          frame.bytesPerPixel,
          'face $faceID',
          frame.bytes,
        )
            .then((_) {
          isComputingFrame = false;
        });
      } else {
        RecognizerInterface()
            .compareFace(
          frame.width,
          frame.height,
          frame.bytesPerPixel,
          frame.bytes,
        )
            .then((_) {
          isComputingFrame = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canBuild) return Container();

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
            // * camera view texture
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // * camera view
                SizedBox(
                  width: width.toDouble(),
                  height: height.toDouble(),
                  child: Stack(
                    children: [
                      Texture(textureId: textureID),
                      ValueListenableBuilder<FacePoints>(
                          valueListenable: _points,
                          builder: (_, points, __) {
                            return FittedBox(
                              child: CustomPaint(
                                size: Size(width.toDouble(), height.toDouble()),
                                painter: PointsPainter(pointsMap: points),
                              ),
                            );
                          }),
                    ],
                  ),
                ),

                const SizedBox(width: 30),

                // * points
                ValueListenableBuilder<FacePoints>(
                    valueListenable: _points,
                    builder: (_, points, __) {
                      if (points.nFaces == 0) {
                        return Container();
                      }

                      return SizedBox(
                        width: 400,
                        child: FittedBox(
                          child: CustomPaint(
                            size: Size(width.toDouble(), height.toDouble()),
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

            // * FPS DLib
            ValueListenableBuilder<String>(
                valueListenable: _textDlib,
                builder: (_, text, __) {
                  return Text('FPS DLib: $text');
                }),

            //* debug image
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('What DLib   \nwill process   '),
                SizedBox(
                  width: 200,
                  child: ValueListenableBuilder<Uint8List>(
                      valueListenable: _adjustedImg,
                      builder: (_, imgBuffer, __) {
                        if (imgBuffer.isEmpty) return Container(height: 0);
                        return Image.memory(imgBuffer, gaplessPlayback: true);
                      }),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // * anti shake
            if (_isDetectMode.value)
              SizedBox(
                width: 400,
                child: ValueListenableBuilder<int>(
                    valueListenable: _antiShake,
                    builder: (_, antiShake, __) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
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
              ),

            const SizedBox(height: 10),

            // * buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // * start camera
                OutlinedButton(
                  child: const Text('start camera'),
                  onPressed: () {
                    OpenCVCamera().openOpenCVCamera();
                    OpenCVCamera().startOpenCVCamera();
                  },
                ),
                // * stop camera
                OutlinedButton(
                  child: const Text('stop camera'),
                  onPressed: () {
                    OpenCVCamera().stopOpenCVCamera();
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // * detector / recognizer buttons
            ValueListenableBuilder<bool>(
                valueListenable: _isDetectMode,
                builder: (_, isDetectMode, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      // * START/STOP dlib
                      OutlinedButton(
                        child: Text(startGrab ? 'Stop DLib' : 'Start DLib'),
                        onPressed: () {
                          if (startGrab) {
                            startGrab = false;
                            timer?.cancel();
                            ticker.stop();
                            if (mounted) setState(() {});
                          } else {
                            startGrab = true;
                            timer?.cancel();
                            if (_isDetectMode.value) {
                              ticker = Ticker(_computeDetectorPoints);
                            } else {
                              ticker = Ticker(_computeRecognize);
                            }
                            ticker.start();

                            /// Timer to modify fps text
                            timer = Timer.periodic(const Duration(milliseconds: 1000),
                                    (timer) {
                                  _textDlib.value = fpsDlib.toString();

                                  // To see what dlib will process
                                  CameraFrame frame =
                                    OpenCVCamera().getRAWOpenCVCameraFrame();
                                  if (_isDetectMode.value) {
                                    DetectorInterface()
                                        .getAdjustedSource(frame.width, frame.height,
                                        frame.bytesPerPixel, frame.bytes)
                                        .then((value) => _adjustedImg.value = value);
                                  } else {
                                    RecognizerInterface()
                                        .getAdjustedSource(frame.width, frame.height,
                                        frame.bytesPerPixel, frame.bytes)
                                        .then((value) => _adjustedImg.value = value);
                                  }
                                  fpsDlib = 0;
                                });
                          }
                          if (mounted) setState(() {});
                        },
                      ),

                      const SizedBox(width: 30),

                      // * detector button
                      OutlinedButton(
                        style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                isDetectMode
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.transparent)),
                        onPressed: () async {
                          if (_isDetectMode.value) return;
                          bool b = ticker.isActive;
                          if (b) {
                            ticker.stop();
                            ticker.dispose();
                          }
                          ticker = Ticker(_computeDetectorPoints);
                          if (b) ticker.start();
                          _isDetectMode.value = true;
                          if (mounted) setState(() {});
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
                          if (!_isDetectMode.value) return;
                          bool b = ticker.isActive;
                          if (b) {
                            ticker.stop();
                            ticker.dispose();
                          }
                          ticker = Ticker(_computeRecognize);
                          if (b) ticker.start();
                          _isDetectMode.value = false;
                          if (mounted) setState(() {});
                        },
                        child: const Text('recognizer'),
                      ),


            const SizedBox(width: 50),


            // * Detect mode: Landmark points / rectangle
            ValueListenableBuilder<bool>(
                valueListenable: _isDetectMode,
                builder: (_, isDetectMode, __) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                      if (!isDetectMode)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              label: const Text('add face'),
                              icon: const Icon(Icons.face),
                              onPressed: () {
                                tryToAddFace = true;
                              },
                            ),

                            const SizedBox(width: 30),

                            // * face image added
                            if (!isDetectMode)
                              ValueListenableBuilder<List<Uint8List>>(
                                  valueListenable: _faceImage,
                                  builder: (_, recognizedFaceImages, __) {
                                    if (recognizedFaceImages.isEmpty) {
                                      return Container();
                                    }
                                    return Row(
                                      children: 
                                        List.generate(recognizedFaceImages.length, 
                                          (index) => Image.memory(
                                            recognizedFaceImages[index],
                                            width: 100,
                                            gaplessPlayback: true,
                                          )
                                      )
                                    );
                                  }
                              ),

                                    
                          ],
                        ),
                    ],
                  );
                }),


                    ],
                  );
                }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
