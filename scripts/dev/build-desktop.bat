@echo off
REM ============================================================================
REM build-desktop.bat - LifeScale Desktop (Windows) build entry (calls build-desktop.ps1)
REM ============================================================================
REM Usage:
REM   .\build-desktop.bat -Version 0.2.0 -Channel beta        (beta/test, NSIS exe)
REM   .\build-desktop.bat -Version 0.2.0 -Channel release      (production, NSIS exe)
REM   .\build-desktop.bat -Version 0.2.0 -Channel release -IncludeMsi   (also build msi)
REM ============================================================================

set "PS1=%~dp0build-desktop.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
pause
exit /b %EXITCODE%
