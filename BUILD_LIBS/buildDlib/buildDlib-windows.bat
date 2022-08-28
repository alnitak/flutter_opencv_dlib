mkdir ../windows/dlib
mkdir build-dlib-win
cd build-dlib-win

cmake -G "Visual Studio 17 2022" -T host=x64 -A win32 ^
-DCMAKE_BUILD_TYPE=MinSizeRel ^
-DBUILD_SHARED_LIBS=OFF ^
-DCMAKE_INSTALL_PREFIX=../libs-windows/dlib ^
..\dlib\dlib

			
cmake --build . --config Release --target INSTALL

cd ..

md ..\..\windows\dlib\lib
xcopy /e /i /f /y  .\libs-windows\dlib\include\ ..\..\windows\dlib\include\
copy /b .\libs-windows\dlib\lib\dlib*.lib ..\..\windows\dlib\lib\dlib.lib
