#include "include/flutter_opencv_dlib/flutter_opencv_dlib_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_opencv_dlib_plugin.h"

void FlutterOpencvDlibPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_opencv_dlib::FlutterOpencvDlibPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
