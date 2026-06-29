@echo off
REM ============================================================================
REM gen-icons.bat - LifeScale app icons regeneration entry (calls gen-icons.ps1)
REM ============================================================================
REM Usage:
REM   .\gen-icons.bat                 (regenerate mobile + desktop icons)
REM   .\gen-icons.bat -AndroidOnly    (mobile only)
REM   .\gen-icons.bat -DesktopOnly    (desktop only)
REM
REM Prerequisites - source images already in place (run after editing source):
REM   mobile : mobile\assets\icons\brand\app_icon_source_1024[_beta].png
REM   desktop: desktop\src-tauri\app-icon.png
REM ============================================================================

set "PS1=%~dp0gen-icons.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "EXITCODE=%ERRORLEVEL%"

echo.
pause
exit /b %EXITCODE%
