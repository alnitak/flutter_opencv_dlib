#import "FlutterOpencvDlibPlugin.h"
#if __has_include(<flutter_opencv_dlib/flutter_opencv_dlib-Swift.h>)
#import <flutter_opencv_dlib/flutter_opencv_dlib-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_opencv_dlib-Swift.h"
#endif

@implementation FlutterOpencvDlibPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterOpencvDlibPlugin registerWithRegistrar:registrar];
}
@end
