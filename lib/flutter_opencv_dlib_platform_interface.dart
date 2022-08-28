import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_opencv_dlib_method_channel.dart';

abstract class FlutterOpencvDlibPlatform extends PlatformInterface {
  /// Constructs a FlutterOpencvDlibPlatform.
  FlutterOpencvDlibPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterOpencvDlibPlatform _instance = MethodChannelFlutterOpencvDlib();

  /// The default instance of [FlutterOpencvDlibPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterOpencvDlib].
  static FlutterOpencvDlibPlatform get instance => _instance;
  
  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterOpencvDlibPlatform] when
  /// they register themselves.
  static set instance(FlutterOpencvDlibPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
