import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'face_points.dart';

/// Bind C functions to Dart
class DetectorInterface {
  static DetectorInterface? _instance;

  late DynamicLibrary _nativeLib;

  late var _setAntiShake;
  late var _setScaleFactor;
  late var _setInputColorSpace;
  late var _setRotation;
  late var _setFlip;
  late var _setGetOnlyRectangle;
  late var _getAdjustedSource;
  final streamImageController = StreamController<Uint8List>();
  final streamPointsController = StreamController<FacePoints>();
  bool isGetAdjustedSource = false;

  factory DetectorInterface() {
    _instance ??= DetectorInterface._internal();
    return _instance!;
  }

  DetectorInterface._internal() {
    _nativeLib = Platform.isAndroid || Platform.isLinux
        ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
        : (Platform.isWindows
            ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
            : DynamicLibrary.process());

    _setAntiShake = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 antiShakeSamples)>>(
            'setDetectorAntiShakeSamples')
        .asFunction<Pointer<Void> Function(int antiShakeSamples)>();

    _setScaleFactor = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Double scale)>>(
            'setDetectorScaleFactor')
        .asFunction<Pointer<Void> Function(double scale)>();

    _setInputColorSpace = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 colorSpace)>>(
            'setDetectorInputColorSpace')
        .asFunction<Pointer<Void> Function(int colorSpace)>();

    _setRotation = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 rotation)>>(
            'setDetectorRotation')
        .asFunction<Pointer<Void> Function(int rotation)>();

    _setFlip = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 flip)>>(
            'setDetectorFlip')
        .asFunction<Pointer<Void> Function(int flip)>();

    _setGetOnlyRectangle = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Bool onlyRectangle)>>(
            'setGetOnlyRectangle')
        .asFunction<Pointer<Void> Function(bool onlyRectangle)>();

    _getAdjustedSource = _nativeLib
        .lookup<
            NativeFunction<
                Pointer<Void> Function(
                    Int32 width,
                    Int32 height,
                    Int32 bytesPerPixel,
                    Pointer<Uint8> imgBytes,
                    Pointer<Pointer<Uint8>> retImg,
                    Pointer<Int32> retImgLength)>>('getDetectorAdjustedSource')
        .asFunction<
            Pointer<Void> Function(
                int width,
                int height,
                int bytesPerPixel,
                Pointer<Uint8> imgBytes,
                Pointer<Pointer<Uint8>> retImg,
                Pointer<Int32> retImgLength)>();
  }

  setAntiShake(int antiShakeSamples) {
    _setAntiShake(antiShakeSamples);
  }

  setScaleFactor(int scale) {
    _setScaleFactor(scale);
  }

  /// source frame color space
  setInputColorSpace(ColorSpace colorSpace) {
    _setInputColorSpace(colorSpace.index);
  }

  ///  0  Rotate 90 degrees clockwise
  ///  1  Rotate 180 degrees clockwise
  ///  2  Rotate 270 degrees clockwise
  ///  other values don't rotate
  setRotation(int rotation) {
    _setRotation(rotation);
  }

  ///  0  flipping around the x-axis
  ///  1  flipping around y-axis
  ///  -1 means flipping around both axes
  ///  other values don't flip
  setFlip(int flip) {
    _setFlip(flip);
  }

  setGetOnlyRectangle(bool onlyRect) {
    _setGetOnlyRectangle(onlyRect);
  }

  /// Return the bitmap which DLib will manage to find face
  Future<Uint8List> getAdjustedSource(
      int width, int height, int bytesPerPixel, Uint8List bytes) async{
    if (bytes.isEmpty || isGetAdjustedSource) return Uint8List(0);
    isGetAdjustedSource = true;

    Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    Pointer<Pointer<Uint8>> retImg = calloc<Pointer<Uint8>>(2);
    Pointer<Int32> retImgLength = calloc<Int32>(4);

    _getAdjustedSource(width, height, bytesPerPixel, buffer,
        retImg, retImgLength);

    int length = retImgLength.value;
    Uint8List ret = Uint8List(length);
    if (length > 0) {
      Pointer<Uint8> imgCppPointer = retImg.elementAt(0).value;
      for (int i=0; i<length; i++){
        ret[i] = retImg.value[i];
      }
      calloc.free(imgCppPointer);
    }
    calloc.free(retImg);
    calloc.free(retImgLength);
    calloc.free(buffer);
    isGetAdjustedSource = false;
    return ret;
  }

  /// Returns a map containing face count and coordinate points
  /// {
  ///    'nFaces': retFaceCount.value,
  ///    'points': points,
  /// }
  bool isGettingFaces = false;
  Future getFacePosePoints(
      int? width, int? height, int? bytesPerPixel, Uint8List bytes) async {
    if (isGettingFaces) return;
    isGettingFaces = true;
    Map params = {
      'width': width ?? 0,
      'height': height ?? 0,
      'bytesPerPixel': bytesPerPixel ?? 0,
      'bytes': bytes,
    };
    compute(getFacePosePointsIsolate, params)
    .then((value) {
      if (value.nFaces > 0) {
        streamPointsController.add(value);
      }
      isGettingFaces = false;
    });

  }

  Future drawFacePose(
      int? width, int? height, int? bytesPerPixel, Uint8List bytes) async {
    Map params = {
      'width': width ?? 0,
      'height': height ?? 0,
      'bytesPerPixel': bytesPerPixel ?? 0,
      'bytes': bytes,
    };
    Uint8List ret = await compute(drawFacePoseIsolate, params);
    streamImageController.add(ret);
  }

  Future<bool> initDetector() async {
    var sp = (await rootBundle.load(
        'packages/flutter_opencv_dlib/assets/shape_predictor_68_face_landmarks.dat'));
    bool ret = await compute(loadShapePredictorIsolate, sp);
    return ret;
  }
}

/*
 * Isolate to call getFacePosePoints
 */
// Future<FacePoints> getFacePosePointsIsolate(Map params) async {
//   DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
//       ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
//       : (Platform.isWindows
//           ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
//           : DynamicLibrary.process());
//
//   var getFacePosePoints = nativeLib
//       .lookup<
//           NativeFunction<
//               Pointer<Int32> Function(
//                   Int32 width,
//                   Int32 height,
//                   Int32 bytesPerPixel,
//                   Pointer<Uint8> imgBytes,
//                   Pointer<Int32> faceCount)>>('getFacePosePoints')
//       .asFunction<
//           Pointer<Int32> Function(int width, int height, int bytesPerPixel,
//               Pointer<Uint8> imgBytes, Pointer<Int32> faceCount)>();
//
//   var getGetOnlyRectangle = nativeLib
//       .lookup<NativeFunction<Bool Function()>>('getGetOnlyRectangle')
//       .asFunction<bool Function()>();
//
//   int width = params['width'];
//   int height = params['height'];
//   int bytesPerPixel = params['bytesPerPixel'];
//   Uint8List bytes = params['bytes'];
//
//   FacePoints ret = FacePoints(0, 0, [], []);
//   using((Arena arena, [malloc]) {
//     final buffer = arena.allocate<Uint8>(bytes.length);
//     for (var i = 0; i < bytes.length; i++) {
//       buffer[i] = bytes[i];
//     }
//     final retFaceCount = arena<Int32>();
//     final retFacePoints =
//         getFacePosePoints(width, height, bytesPerPixel, buffer, retFaceCount);
//
//     if (retFacePoints != nullptr) {
//       bool onlyRect = getGetOnlyRectangle();
//       List<int> points = retFacePoints
//           .asTypedList(retFaceCount.value * (onlyRect ? 2 : 68) * 2)
//           .toList();
//       ret =
//           FacePoints(retFaceCount.value, (onlyRect ? 2 : 68), points, []);
//     }
//   });
//
//   return ret;
// }

Future<FacePoints> getFacePosePointsIsolate(Map params) async {
  DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
      ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
      : (Platform.isWindows
          ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
          : DynamicLibrary.process());

  var getFacePosePoints = nativeLib
      .lookup<
          NativeFunction<
              Pointer<Int32> Function(
                  Int32 width,
                  Int32 height,
                  Int32 bytesPerPixel,
                  Pointer<Uint8> imgBytes,
                  Pointer<Int32> faceCount)>>('getFacePosePoints')
      .asFunction<
          Pointer<Int32> Function(int width, int height, int bytesPerPixel,
              Pointer<Uint8> imgBytes, Pointer<Int32> faceCount)>();

  var getGetOnlyRectangle = nativeLib
      .lookup<NativeFunction<Bool Function()>>('getGetOnlyRectangle')
      .asFunction<bool Function()>();

  int width = params['width'];
  int height = params['height'];
  int bytesPerPixel = params['bytesPerPixel'];
  Uint8List bytes = params['bytes'];

  Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
  buffer.asTypedList(bytes.length).setAll(0, bytes);
  Pointer<Int32> retFaceCount = calloc<Int32>(4);
  Pointer<Int32> retFacePoints =
      getFacePosePoints(width, height, bytesPerPixel, buffer, retFaceCount);

  if (retFacePoints == nullptr) {
    calloc.free(retFaceCount);
    calloc.free(buffer);
    return FacePoints(0, 0, [], []);
  }
  bool onlyRect = getGetOnlyRectangle();
  List<int> points = retFacePoints
      .asTypedList(retFaceCount.value * (onlyRect ? 2 : 68) * 2)
      .toList();

  FacePoints ret =
      FacePoints(retFaceCount.value, (onlyRect ? 2 : 68), points, []);
  calloc.free(retFaceCount);
  calloc.free(retFacePoints);
  calloc.free(buffer);
  return ret;
}







/*
 * Isolate to call drawFacePose
 */
Future<Uint8List> drawFacePoseIsolate(Map params) async {
  DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
      ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
      : (Platform.isWindows
          ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
          : DynamicLibrary.process());

  var drawFacePose = nativeLib
      .lookup<
          NativeFunction<
              Pointer<Uint8> Function(
                  Int32 width,
                  Int32 height,
                  Int32 bytesPerPixel,
                  Pointer<Uint8> imgBytes,
                  Pointer<Int32> retImgLength)>>('drawFacePose')
      .asFunction<
          Pointer<Uint8> Function(int width, int height, int bytesPerPixel,
              Pointer<Uint8> imgBytes, Pointer<Int32> retImgLength)>();

  int width = params['width'];
  int height = params['height'];
  int bytesPerPixel = params['bytesPerPixel'];
  Uint8List bytes = params['bytes'];

  // TODO converting images takes a lot. Write a C function to load it!
  Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    buffer[i] = bytes[i];
  }
  Pointer<Uint8> retImg = calloc<Uint8>(0);
  Pointer<Int32> retImgLength = calloc<Int32>(4);
  retImg = drawFacePose(width, height, bytesPerPixel, buffer, retImgLength);

  int length = retImgLength.value;
  Uint8List ret = retImg.asTypedList(length);

  calloc.free(retImg);
  calloc.free(retImgLength);
  calloc.free(buffer);
  return ret;
}

/*
 * Isolate to load shape predictor data file
 */
Future<bool> loadShapePredictorIsolate(var sp) async {
  DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
      ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
      : (Platform.isWindows
      ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
      : DynamicLibrary.process());

  var _initDetector = nativeLib
      .lookup<
          NativeFunction<
              Pointer<Void> Function(
                  Pointer<Int8> shapePredictor, Int64 size)>>('initDetector')
      .asFunction<
          Pointer<Void> Function(Pointer<Int8> shapePredictor, int size)>();

  // TODO converting this 95MB file takes ages. Write a C function to load it!
  Uint8List bytes = sp.buffer.asUint8List();
  Pointer<Int8> buffer = calloc<Int8>(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    buffer[i] = bytes[i];
  }

  _initDetector(buffer, bytes.length);
  calloc.free(buffer);
  return true;
}
