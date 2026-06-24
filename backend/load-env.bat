@echo off
REM ============================================================================
REM LifeScale backend .env loader (Windows batch)
REM ----------------------------------------------------------------------------
REM Purpose: parse the project-root .env and inject KEY=VALUE into the caller's
REM          environment so mvn spring-boot:run can read LIFESCALE_COS_* etc.
REM
REM .env location: project root (this file is in code/backend/, root is ../..).
REM Usage:        call load-env.bat   (MUST use call so vars return to caller)
REM
REM Design notes:
REM   - No setlocal/endlocal: ensures set vars survive return to caller.
REM   - Caller must have EnableDelayedExpansion (start.bat sets it).
REM   - Parses only KEY=VALUE; skips # comment lines and blank lines.
REM   - Strips one pair of surrounding double-quotes from the value.
REM ============================================================================

set "ENV_FILE=%~dp0..\..\.env"
if not exist "%ENV_FILE%" (
  echo [load-env] .env not found: %ENV_FILE% ^(will use application.yml defaults^) 1>&2
  goto :eof
)

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  call :ParseLine "%%A" "%%B"
)
echo [load-env] loaded "%ENV_FILE%" into process environment 1>&2
goto :eof

REM ---- subroutine: parse one line ----
:ParseLine
set "_KEY=%~1"
if not defined _KEY goto :ParseEnd
REM skip comment lines starting with #
if "%_KEY:~0,1%"=="#" goto :ParseEnd
set "_VAL=%~2"
if defined _VAL set "_VAL=%_VAL:"=%"
if defined _KEY set "%_KEY%=%_VAL%"
:ParseEnd
set "_KEY="
set "_VAL="
goto :eof
