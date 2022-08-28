#ifndef FLUTTER_PLUGIN_FLUTTER_OPENCV_DLIB_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_OPENCV_DLIB_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_opencv_dlib {

class FlutterOpencvDlibPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterOpencvDlibPlugin();

  virtual ~FlutterOpencvDlibPlugin();

  // Disallow copy and assign.
  FlutterOpencvDlibPlugin(const FlutterOpencvDlibPlugin&) = delete;
  FlutterOpencvDlibPlugin& operator=(const FlutterOpencvDlibPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_opencv_dlib

#endif  // FLUTTER_PLUGIN_FLUTTER_OPENCV_DLIB_PLUGIN_H_
