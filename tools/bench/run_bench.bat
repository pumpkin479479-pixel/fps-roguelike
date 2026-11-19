@echo off
chcp 65001 >nul
rem 弾幕の負荷テストを実行して結果を表示する(Windows)。
rem Godot の場所は環境変数 GODOT で変えられる。既定は winget で入れた場所。
setlocal
if "%GODOT%"=="" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
cd /d "%~dp0..\.."
"%GODOT%" --path . res://scenes/bench.tscn -- --quit %*
echo.
echo 結果の CSV は %APPDATA%\Godot\app_userdata\fps-roguelike\bench にあります。
endlocal
