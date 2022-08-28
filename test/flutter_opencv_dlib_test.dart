import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_opencv_dlib/flutter_opencv_dlib.dart';
import 'package:flutter_opencv_dlib/flutter_opencv_dlib_platform_interface.dart';
import 'package:flutter_opencv_dlib/flutter_opencv_dlib_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterOpencvDlibPlatform 
    with MockPlatformInterfaceMixin
    implements FlutterOpencvDlibPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterOpencvDlibPlatform initialPlatform = FlutterOpencvDlibPlatform.instance;

  test('$MethodChannelFlutterOpencvDlib is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterOpencvDlib>());
  });

  test('getPlatformVersion', () async {
    FlutterOpencvDlib flutterOpencvDlibPlugin = FlutterOpencvDlib();
    MockFlutterOpencvDlibPlatform fakePlatform = MockFlutterOpencvDlibPlatform();
    FlutterOpencvDlibPlatform.instance = fakePlatform;
  
    expect(await flutterOpencvDlibPlugin.getPlatformVersion(), '42');
  });
}
