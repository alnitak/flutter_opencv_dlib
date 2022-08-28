mkdir ../windows/opencv
mkdir build-opencv-win
cd build-opencv-win

REM OpenCV options reference
REM https://docs.opencv.org/4.x/db/d05/tutorial_config_reference.html

cmake -G "Visual Studio 17 2022" -T host=x64 -A win32 ^
-DCMAKE_BUILD_TYPE=Release ^
-DCMAKE_BUILD_TYPE=MinSizeRel ^
-DBUILD_SHARED_LIBS=ON ^
-DOPENCV_VS_VERSIONINFO_SKIP=1 ^
-DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules/ ^
-DCMAKE_INSTALL_PREFIX=../../windows/opencv ^
..\opencv

cmake --build . --config Release --target INSTALL
	
cd ..