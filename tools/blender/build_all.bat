@echo off
chcp 65001 >nul
rem 銃モデルをすべて作り直す(Windows)。画像は tools\blender\renders に出る(Git には入れない)。
setlocal
if "%BLENDER%"=="" set "BLENDER=C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
cd /d "%~dp0..\.."
"%BLENDER%" -b -P tools/blender/ak47.py -- --out assets/models/guns/ak47.glb --render tools/blender/renders
endlocal
