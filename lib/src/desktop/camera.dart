import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

class CameraFrame {
  int width;
  int height;
  int bytesPerPixel;
  Uint8List bytes;

  CameraFrame(
      this.width,
      this.height,
      this.bytesPerPixel,
      this.bytes,
  );
}

class OpenCVCamera {
  static OpenCVCamera? _instance;
  static const MethodChannel _channel = MethodChannel('flutter_opencv_dlib');

  late DynamicLibrary _nativeLib;
  late var _openPointer;
  late var _startPointer;
  late var _stopPointer;
  late var _getBMPFramePointer;
  late var _getRAWFramePointer;

  factory OpenCVCamera() {
    _instance ??= OpenCVCamera._internal();
    return _instance!;
  }

  OpenCVCamera._internal() {
    _nativeLib = Platform.isAndroid || Platform.isLinux
        ? DynamicLibrary.open("libflutter_opencv_dlib_plugin.so")
        : (Platform.isWindows
            ? DynamicLibrary.open("flutter_opencv_dlib_plugin.dll")
            : DynamicLibrary.process());

    _openPointer = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function()>>('openOpenCVCamera')
        .asFunction<Pointer<Void> Function()>();

    _startPointer = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function()>>('startOpenCVCamera')
        .asFunction<Pointer<Void> Function()>();

    _stopPointer = _nativeLib
        .lookup<NativeFunction<Pointer<Void> Function()>>('stopOpenCVCamera')
        .asFunction<Pointer<Void> Function()>();

    _getBMPFramePointer = _nativeLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(
                    Pointer<Int32> retImgLength)>>('getBMPCameraFrame')
        .asFunction<Pointer<Uint8> Function(Pointer<Int32> retImgLength)>();

    _getRAWFramePointer = _nativeLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(
                    Pointer<Int32> width,
                    Pointer<Int32> height,
                    Pointer<Int32> bytesPerPixel,
                    Pointer<Int32> retImgLength)>>('getRAWCameraFrame')
        .asFunction<
            Pointer<Uint8> Function(Pointer<Int32> width, Pointer<Int32> height,
                Pointer<Int32> bytesPerPixel, Pointer<Int32> retImgLength)>();
  }

  Future<int?> registerTexture(int width, int height) async {
    final int? textureId = await _channel
        .invokeMethod('registerTexture', {'width': width, 'height': height});
    return textureId;
  }

  openOpenCVCamera() {
    _openPointer();
  }

  startOpenCVCamera() {
    _startPointer();
  }

  stopOpenCVCamera() {
    _stopPointer();
  }

  Uint8List getBMPOpenCVCameraFrame() {
    Pointer<Uint8> retImg = calloc<Uint8>(2);
    Pointer<Int32> retImgLength = calloc<Int32>(4);
    retImg = _getBMPFramePointer(retImgLength);
    if (retImg == nullptr) {
      calloc.free(retImg);
      calloc.free(retImgLength);
      return Uint8List(0);
    }

    int length = retImgLength.value;
    Uint8List ret = Uint8List(length);
    if (length > 0) {
      for (int i=0; i<length; i++){
        ret[i] = retImg[i];
      }
    }

    calloc.free(retImg);
    calloc.free(retImgLength);
    return ret;
  }

  CameraFrame getRAWOpenCVCameraFrame() {
    Pointer<Uint8> retImg = calloc<Uint8>(2);
    Pointer<Int32> width = calloc<Int32>(4);
    Pointer<Int32> height = calloc<Int32>(4);
    Pointer<Int32> bytesPerPixel = calloc<Int32>(4);
    Pointer<Int32> retImgLength = calloc<Int32>(4);
    retImg = _getRAWFramePointer(
      width,
      height,
      bytesPerPixel,
      retImgLength
    );
    if (retImg == nullptr) {
      calloc.free(retImg);
      calloc.free(width);
      calloc.free(height);
      calloc.free(bytesPerPixel);
      calloc.free(retImgLength);
      return CameraFrame(0, 0, 0, Uint8List(0));
    }

    int length = retImgLength.value;
    CameraFrame ret = CameraFrame(
      width.value,
      height.value,
      bytesPerPixel.value,
      Uint8List(length),
    );
    if (length > 0) {
      for (int i=0; i<length; i++){
        ret.bytes[i] = retImg[i];
      }
    }

    calloc.free(retImg);
    calloc.free(width);
    calloc.free(height);
    calloc.free(bytesPerPixel);
    calloc.free(retImgLength);
    return ret;
  }

}
