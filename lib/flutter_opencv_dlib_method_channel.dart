import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_opencv_dlib_platform_interface.dart';

/// An implementation of [FlutterOpencvDlibPlatform] that uses method channels.
class MethodChannelFlutterOpencvDlib extends FlutterOpencvDlibPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_opencv_dlib');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
