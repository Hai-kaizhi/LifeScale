@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM LifeScale mobile - one-click run (debug)
REM   1. preflight backend health (GET /api/health)
REM   2. flutter pub get + build_runner build
REM   3. pick target: real device -> LAN IP ; else boot API36 emulator -> 10.0.2.2
REM   4. flutter run (foreground; press r to hot reload, q to quit)
REM log: code\logs\mobile.log
REM NOTE: keep this file pure ASCII; cmd on Chinese Windows mis-parses
REM       UTF-8 Chinese bytes as GBK and breaks command tokenization.
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "MOBILE_DIR=%SCRIPT_DIR%.."
set "CODE_DIR=%SCRIPT_DIR%..\.."
set "LOG_DIR=%CODE_DIR%\logs"
set "LOG_FILE=%LOG_DIR%\mobile.log"
set "ADB=E:\AndroidSdk\platform-tools\adb.exe"
set "EMULATOR=E:\AndroidSdk\emulator\emulator.exe"
set "AVD=Medium_Phone_API_36.0"

set "ANDROID_SDK_ROOT=E:\AndroidSdk"
set "ANDROID_HOME=E:\AndroidSdk"
set "JAVA_HOME=E:\java21"
set "PATH=E:\AndroidSdk\platform-tools;%PATH%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo [LifeScale] Preflight backend health (GET /api/health) ...
call :WaitBackend 30
if errorlevel 1 (
  echo [ERROR] Backend not ready. Run code\start.bat first - needs PostgreSQL/Redis/Spring Boot.
  exit /b 1
)

pushd "%MOBILE_DIR%" >nul

echo [LifeScale] flutter pub get ...
call flutter pub get
if errorlevel 1 (
  echo [LifeScale] first attempt failed, retry ...
  call flutter pub get
)

echo [LifeScale] build_runner build ...
call dart run build_runner build --delete-conflicting-outputs

REM detect host LAN IP up front (used only for real-device target)
call :DetectLanIp

REM pick target. LIFESCALE_USE_MOCK_API=false forces real backend (mock-first otherwise).
set "DART_DEFINE=--dart-define=LIFESCALE_USE_MOCK_API=false --dart-define=LIFESCALE_API_BASE_URL=http://10.0.2.2:8080/api --dart-define=LIFESCALE_IS_EMULATOR=true"
set "TARGET=emulator"
for /f "tokens=1,2" %%a in ('"%ADB%" devices 2^>nul') do (
  if /i "%%b"=="device" (
    set "DID=%%a"
    if /i not "!DID:~0,8!"=="emulator" set "TARGET=device"
  )
)

if /i "!TARGET!"=="device" (
  echo [LifeScale] Real device detected, API base = LAN IP: !LAN_IP!
  set "DART_DEFINE=--dart-define=LIFESCALE_USE_MOCK_API=false --dart-define=LIFESCALE_API_BASE_URL=http://!LAN_IP!:8080/api --dart-define=LIFESCALE_IS_EMULATOR=false"
) else (
  echo [LifeScale] No real device, starting emulator !AVD! ...
  start "" "%EMULATOR%" -avd %AVD% -no-snapshot-load
  echo [LifeScale] Waiting for emulator to register with adb ...
  "%ADB%" wait-for-device
)

echo.
echo [LifeScale] flutter run, target=!TARGET!. Press r = hot reload, q = quit.
echo ---- flutter run target=!TARGET! at %date% %time% ---- >> "%LOG_FILE%"
call flutter run !DART_DEFINE!

popd >nul
exit /b 0

REM ============================ subroutines ============================

:WaitBackend
set "LIMIT=%~1"
for /L %%I in (1,1,%LIMIT%) do (
  call :CheckBackend
  if not errorlevel 1 (
    echo [LifeScale] Backend ready, status=UP.
    exit /b 0
  )
  ping -n 3 127.0.0.1 >nul
)
exit /b 1

:CheckBackend
powershell -NoProfile -Command "try { $r = Invoke-RestMethod -Uri 'http://localhost:8080/api/health' -TimeoutSec 2; if ($r.status -eq 'UP') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
exit /b %errorlevel%

:DetectLanIp
set "LAN_IP="
REM prefer adapter that has a default gateway (real LAN/Wi-Fi, excludes WSL/virtual)
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } | Select-Object -First 1).IPv4Address.IPAddress"`) do if not defined LAN_IP set "LAN_IP=%%i"
REM fallback: any private IPv4
if not defined LAN_IP for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } | Select-Object -First 1).IPAddress"`) do if not defined LAN_IP set "LAN_IP=%%i"
if not defined LAN_IP (
  echo [WARN] No LAN IP detected; real device may not reach backend. Fallback 10.0.2.2 emulator-only.
  set "LAN_IP=10.0.2.2"
)
goto :eof
