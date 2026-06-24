@echo off
REM Boot API36 emulator (matches Vivo X100 Android 16).
REM NOTE: keep this file pure ASCII (see run.bat header).
set "ADB=E:\AndroidSdk\platform-tools\adb.exe"
set "EMULATOR=E:\AndroidSdk\emulator\emulator.exe"
set "AVD=Medium_Phone_API_36.0"

echo [LifeScale] Starting emulator %AVD% ...
start "" "%EMULATOR%" -avd %AVD% -no-snapshot-load

echo [LifeScale] Waiting for device ...
"%ADB%" wait-for-device
"%ADB%" devices
echo [LifeScale] Emulator ready. Run run.bat or the VSCode emulator config.
exit /b 0
