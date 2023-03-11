import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'common.dart';

class RecognizedFace {
  Uint8List face;
  List<int> rectPoints;
  String name;

  /// should check only when adding face
  bool alreadyExists;

  RecognizedFace(
    this.face,
    this.rectPoints,
    this.name,
    this.alreadyExists,
  );
}

class FaceStruct extends Struct {
  external Pointer<Uint8> faceImg;

  @Int32()
  external int imgSize;

  @Int32()
  external int left;

  @Int32()
  external int top;

  @Int32()
  external int bottom;

  @Int32()
  external int right;

  external Pointer<Utf8> name;

  @Bool()
  external bool alreadyExists;
}

/// Bind C functions to Dart
class RecognizerInterface {
  static RecognizerInterface? _instance;

  late DynamicLibrary _nativeLib;

  late var _setScaleFactor;
  late var _setInputColorSpace;
  late var _setRotation;
  late var _setFlip;
  late var _getAdjustedSource;
  final streamAddFaceController = StreamController<RecognizedFace>();
  final streamCompareFaceController = StreamController<List<RecognizedFace>>();
  bool isGetAdjustedSource = false;

  factory RecognizerInterface() {
    _instance ??= RecognizerInterface._internal();
    return _instance!;
  }

  RecognizerInterface._internal() {
    _nativeLib = Platform.isAndroid || Platform.isLinux
        ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
        : (Platform.isWindows
            ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
            : DynamicLibrary.process());

    _setScaleFactor = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Double scale)>>(
            'setRecognizerScaleFactor')
        .asFunction<Pointer<Void> Function(double scale)>();

    _setInputColorSpace = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 colorSpace)>>(
            'setRecognizerInputColorSpace')
        .asFunction<Pointer<Void> Function(int colorSpace)>();

    _setRotation = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 rotation)>>(
            'setRecognizerRotation')
        .asFunction<Pointer<Void> Function(int rotation)>();

    _setFlip = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function(Int32 flip)>>(
            'setRecognizerFlip')
        .asFunction<Pointer<Void> Function(int flip)>();

    _getAdjustedSource = _nativeLib
        .lookup<
                NativeFunction<
                    Pointer<Void> Function(
                        Int32 width,
                        Int32 height,
                        Int32 bytesPerPixel,
                        Pointer<Uint8> imgBytes,
                        Pointer<Pointer<Uint8>> retImg,
                        Pointer<Int32> retImgLength)>>(
            'getRecognizerAdjustedSource')
        .asFunction<
            Pointer<Void> Function(
                int width,
                int height,
                int bytesPerPixel,
                Pointer<Uint8> imgBytes,
                Pointer<Pointer<Uint8>> retImg,
                Pointer<Int32> retImgLength)>();
  }

  Future<bool> initRecognizer() async {
    // ! rootBundle doesn't work on isolates
    var sp = (await rootBundle.load(
        'packages/flutter_opencv_dlib/assets/shape_predictor_5_face_landmarks-B.dat'));
    var fr = (await rootBundle.load(
        'packages/flutter_opencv_dlib/assets/dlib_face_recognition_resnet_model_v1.dat'));
    bool ret = await compute(loadRecognizerIsolate, {'sp': sp, 'fr': fr});
    return ret;
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
  ///  other values doesn't rotate
  setRotation(int rotation) {
    _setRotation(rotation);
  }

  ///  0  flipping around the x-axis
  ///  1  flipping around y-axis
  ///  -1 means flipping around both axes
  ///  other values doesn't flip
  setFlip(int flip) {
    _setFlip(flip);
  }

  /// Return the bitmap which DLib will manage to find face
  Future<Uint8List> getAdjustedSource(
      int width, int height, int bytesPerPixel, Uint8List bytes) async {
    if (bytes.isEmpty || isGetAdjustedSource) return Uint8List(0);
    isGetAdjustedSource = true;

    Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    Pointer<Pointer<Uint8>> retImg = calloc<Pointer<Uint8>>(2);
    Pointer<Int32> retImgLength = calloc<Int32>(4);

    Uint8List ret = Uint8List(0);
    try {
      _getAdjustedSource(
          width, height, bytesPerPixel, buffer, retImg, retImgLength);

      int length = retImgLength.value;
      ret = Uint8List(length);
      if (length > 0) {
        Pointer<Uint8> imgCppPointer = retImg.elementAt(0).value;
        for (int i = 0; i < length; i++) {
          ret[i] = retImg.value[i];
        }
        calloc.free(imgCppPointer);
      }
      calloc.free(retImg);
      calloc.free(retImgLength);
      calloc.free(buffer);
    } catch (e) {
      debugPrint('getAdjustedSource error: $e');
    }
    isGetAdjustedSource = false;
    return ret;
  }

  Future<RecognizedFace?> addFace(
    int width,
    int height,
    int bytesPerPixel,
    String name,
    Uint8List bytes,
  ) async {
    Map params = {
      'width': width,
      'height': height,
      'bytesPerPixel': bytesPerPixel,
      'name': name,
      'bytes': bytes,
    };
    // TODO togliere await e mettere streamAddFaceController dentro il then?
    RecognizedFace? ret = await compute(addFaceIsolate, params);
    if (ret != null) {
      streamAddFaceController.add(ret);
    }
    return ret;
  }

  bool isComparingFaces = false;

  Future compareFace(
    int width,
    int height,
    int bytesPerPixel,
    Uint8List bytes,
  ) async {
    if (isComparingFaces) return [];
    isComparingFaces = true;
    Map params = {
      'width': width,
      'height': height,
      'bytesPerPixel': bytesPerPixel,
      'bytes': bytes,
    };
    compute(compareFaceIsolate, params).then((value) {
      streamCompareFaceController.add(value);
      isComparingFaces = false;
    });
  }
}

/*
 * Isolate to call compareFace
 */
Future<List<RecognizedFace>> compareFaceIsolate(Map params) async {
  DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
      ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
      : (Platform.isWindows
          ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
          : DynamicLibrary.process());

  var compareFaces = nativeLib
      .lookup<
          NativeFunction<
              Pointer<Void> Function(
                  Int32 width,
                  Int32 height,
                  Int32 bytesPerPixel,
                  Pointer<Uint8> imgBytes,
                  Pointer<Pointer<FaceStruct>> faceStruct,
                  Pointer<Int32> faceCount)>>('compareFaces')
      .asFunction<
          Pointer<Void> Function(
              int width,
              int height,
              int bytesPerPixel,
              Pointer<Uint8> imgBytes,
              Pointer<Pointer<FaceStruct>> faceStruct,
              Pointer<Int32> faceCount)>();

  int width = params['width'];
  int height = params['height'];
  int bytesPerPixel = params['bytesPerPixel'];
  Uint8List bytes = params['bytes'];

  Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
  buffer.asTypedList(bytes.length).setAll(0, bytes);

  Pointer<Pointer<FaceStruct>> resultingFaces =
      calloc.allocate(sizeOf<FaceStruct>());

  Pointer<Int32> nReconFaces = calloc<Int32>(4);

  compareFaces(
      width, height, bytesPerPixel, buffer, resultingFaces, nReconFaces);
  calloc.free(buffer);
  if (resultingFaces == nullptr || nReconFaces.value == 0) {
    calloc.free(nReconFaces);
    return [];
  }

  List<RecognizedFace> ret = [];
  for (int i = 0; i < nReconFaces.value; ++i) {
    FaceStruct fs = resultingFaces[i].ref;
    int size = fs.imgSize;
    Uint8List img = Uint8List(size);
    img.setAll(0, fs.faceImg.asTypedList(size));
    fs.faceImg.asTypedList(size);

    List<int> rect = [fs.left, fs.top, fs.right, fs.bottom];

    String name = fs.name == nullptr ? '' : fs.name.toDartString();
    ret.add(RecognizedFace(img, rect, name, false));

    if (resultingFaces[i].ref.faceImg != nullptr) {
      calloc.free(resultingFaces[i].ref.faceImg);
    }
    if (resultingFaces[i] != nullptr) {
      calloc.free(resultingFaces[i]);
    }
  }

  calloc.free(nReconFaces);
  calloc.free(resultingFaces);

  return ret;
}

/*
 * Isolate to call addFace
 */
Future<RecognizedFace?> addFaceIsolate(Map params) async {
  DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
      ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
      : (Platform.isWindows
          ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
          : DynamicLibrary.process());

  final addFace = nativeLib
      .lookup<
          NativeFunction<
              Pointer<FaceStruct> Function(
                  Int32 width,
                  Int32 height,
                  Int32 bytesPerPixel,
                  Pointer<Utf8> name,
                  Pointer<Uint8> imgBytes)>>('addFace')
      .asFunction<
          Pointer<FaceStruct> Function(int width, int height, int bytesPerPixel,
              Pointer<Utf8> name, Pointer<Uint8> imgBytes)>();

  int width = params['width'];
  int height = params['height'];
  int bytesPerPixel = params['bytesPerPixel'];
  String name = params['name'];
  Uint8List bytes = params['bytes'];

  Pointer<Uint8> buffer = calloc<Uint8>(bytes.length);
  buffer.asTypedList(bytes.length).setAll(0, bytes);

  Pointer<FaceStruct> resultingFace =
      addFace(width, height, bytesPerPixel, name.toNativeUtf8(), buffer);
  if (resultingFace == nullptr) return null;

  RecognizedFace? ret;
  FaceStruct? fs = resultingFace.ref;
  if (fs.imgSize > 100) {
    ret = RecognizedFace(
      fs.faceImg.asTypedList(fs.imgSize),
      [fs.left, fs.top, fs.right, fs.bottom],
      fs.name == nullptr ? '' : fs.name.toDartString(),
      fs.alreadyExists,
    );
    calloc.free(resultingFace.ref.faceImg);
  }
  calloc.free(resultingFace);
  calloc.free(buffer);

  return ret;
}

/*
 * Isolate to load shape predictor data file
 */
Future<bool> loadRecognizerIsolate(var models) async {
  DynamicLibrary nativeLib = Platform.isAndroid || Platform.isLinux
      ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
      : (Platform.isWindows
          ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
          : DynamicLibrary.process());

  var initRecognizer = nativeLib
      .lookup<
          NativeFunction<
              Pointer<Void> Function(
                  Pointer<Int8> shapePredictor,
                  Int64 sizeSp,
                  Pointer<Int8> faceRecognition,
                  Int64 sizeFr)>>('initRecognition')
      .asFunction<
          Pointer<Void> Function(Pointer<Int8> shapePredictor, int sizeSp,
              Pointer<Int8> faceRecognition, int sizeFr)>();

  // TODO converting this file takes ages. Write a C function to load it!
  Uint8List bytesSp = models['sp'].buffer.asUint8List();
  Pointer<Int8> bufferSp = calloc<Int8>(bytesSp.length);
  for (var i = 0; i < bytesSp.length; i++) {
    bufferSp[i] = bytesSp[i];
  }
  Uint8List bytesFr = models['fr'].buffer.asUint8List();
  Pointer<Int8> bufferFr = calloc<Int8>(bytesFr.length);
  for (var i = 0; i < bytesFr.length; i++) {
    bufferFr[i] = bytesFr[i];
  }

  initRecognizer(bufferSp, bytesSp.length, bufferFr, bytesFr.length);
  calloc.free(bufferFr);
  calloc.free(bufferSp);
  return true;
}
