@echo off
REM ============================================================================
REM build-android.bat - LifeScale Android build entry (calls build-android.ps1)
REM ============================================================================
REM Usage:
REM   .\build-android.bat -Version 0.2.0 -Channel beta        (beta/test build)
REM   .\build-android.bat -Version 0.2.0 -Channel release      (production build)
REM   .\build-android.bat -Version 0.2.0 -Channel beta -BuildNumber 5
REM ============================================================================

set "PS1=%~dp0build-android.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
pause
exit /b %EXITCODE%
