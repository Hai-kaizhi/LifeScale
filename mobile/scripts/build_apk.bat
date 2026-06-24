@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM LifeScale mobile - build release APK (for real-device sideload)
REM   auto-detects host LAN IP and injects it as API base.
REM NOTE: keep this file pure ASCII (see run.bat header).
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "MOBILE_DIR=%SCRIPT_DIR%.."
set "LOG_DIR=%SCRIPT_DIR%..\..\logs"
set "LOG_FILE=%LOG_DIR%\mobile-build.log"
set "ADB=E:\AndroidSdk\platform-tools\adb.exe"

set "ANDROID_SDK_ROOT=E:\AndroidSdk"
set "ANDROID_HOME=E:\AndroidSdk"
set "JAVA_HOME=E:\java21"
set "PATH=E:\AndroidSdk\platform-tools;%PATH%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :DetectLanIp
if "%LAN_IP%"=="10.0.2.2" echo [WARN] No LAN IP detected; real device may not reach backend.

pushd "%MOBILE_DIR%" >nul

echo [LifeScale] flutter pub get ...
call flutter pub get
echo [LifeScale] build_runner build ...
call dart run build_runner build --delete-conflicting-outputs

echo [LifeScale] Building release APK, API base http://%LAN_IP%:8080/api ...
call flutter build apk --release ^
  --dart-define=LIFESCALE_USE_MOCK_API=false ^
  --dart-define=LIFESCALE_API_BASE_URL=http://%LAN_IP%:8080/api ^
  --dart-define=LIFESCALE_IS_EMULATOR=false
if errorlevel 1 (
  echo [ERROR] Build failed. See %LOG_FILE%
  popd >nul
  exit /b 1
)
popd >nul

set "APK=%MOBILE_DIR%\build\app\outputs\flutter-apk\app-release.apk"
echo.
echo [LifeScale] Build OK:
echo   %APK%
echo.
echo Install on device, enable USB debugging and USB install first:
echo   "%ADB%" install -r "%APK%"
exit /b 0

:DetectLanIp
set "LAN_IP="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } | Select-Object -First 1).IPv4Address.IPAddress"`) do if not defined LAN_IP set "LAN_IP=%%i"
if not defined LAN_IP for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } | Select-Object -First 1).IPAddress"`) do if not defined LAN_IP set "LAN_IP=%%i"
if not defined LAN_IP set "LAN_IP=10.0.2.2"
goto :eof
