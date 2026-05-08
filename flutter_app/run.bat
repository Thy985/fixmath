@echo off
REM FormulaFix Flutter Runner
REM 将此脚本放在 flutter_app 目录下运行

echo ========================================
echo FormulaFix Flutter Runner
echo ========================================

REM 设置 Flutter 路径
set FLUTTER_ROOT=C:\flutter\flutter
set PATH=%FLUTTER_ROOT%\bin;%PATH%

REM 切换到脚本目录
cd /d "%~dp0"

echo.
echo [1/3] 检查 Flutter 版本...
call flutter --version

echo.
echo [2/3] 安装依赖...
call flutter pub get

echo.
echo [3/3] 运行应用...
call flutter run

pause
