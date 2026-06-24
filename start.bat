@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
set "DOCKER_DIR=%ROOT%docker"
set "BACKEND_DIR=%ROOT%backend"
set "DESKTOP_DIR=%ROOT%desktop"
set "LOG_DIR=%ROOT%logs"
set "DOCKER_LOG=%LOG_DIR%\docker.log"
set "BACKEND_LOG=%LOG_DIR%\backend.log"
set "DESKTOP_LOG=%LOG_DIR%\desktop.log"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo [LifeScale] 启动目录：%ROOT%
echo [LifeScale] 检查 Docker Desktop 与 Docker Compose...
docker info >nul 2>&1
if errorlevel 1 (
  echo [错误] Docker 当前不可用，请确认 Docker Desktop 已启动。
  exit /b 1
)

docker compose version >nul 2>&1
if errorlevel 1 (
  echo [错误] 未检测到 docker compose，请确认 Docker Desktop 已正确安装。
  exit /b 1
)

REM ============================================================================
REM 启动前自检：清理可能残留的全栈容器（lifescale-backend 会抢占 8080 端口）
REM 原因：曾跑过 docker-compose.full.yml（全栈容器化验证）会留下 lifescale-backend 容器，
REM 它绑定 127.0.0.1:8080，与后续 mvn spring-boot:run 抢端口，导致 start.bat 行为混乱。
REM ============================================================================
echo [LifeScale] 自检：清理可能残留的全栈容器（避免抢占 8080 端口）...
call :CleanupStaleBackend

REM ============================================================================
REM 启动前自检：8080 端口占用情况
REM - 若被残留的全栈 backend 容器占用（已由上一步清理，正常应已释放）
REM - 若被其他未知进程占用，直接报错让用户处理，避免 mvn 启动失败后无从排查
REM ============================================================================
echo [LifeScale] 自检：检查 8080 端口是否被占用...
call :CheckPort8080
if errorlevel 1 exit /b 1

echo [LifeScale] 启动 PostgreSQL 与 Redis 依赖服务...
pushd "%DOCKER_DIR%" >nul
docker compose up -d >> "%DOCKER_LOG%" 2>&1
if errorlevel 1 (
  popd >nul
  echo [错误] Docker 依赖服务启动失败。最近日志：%DOCKER_LOG%
  exit /b 1
)
popd >nul

call :WaitContainer lifescale-postgres 60
if errorlevel 1 exit /b 1

call :WaitContainer lifescale-redis 60
if errorlevel 1 exit /b 1

call :CheckBackend
if errorlevel 1 (
  echo [LifeScale] 启动 Spring Boot 后端服务...
  echo.>> "%BACKEND_LOG%"
  echo ===== %date% %time% 启动后端 =====>> "%BACKEND_LOG%"
  start "LifeScale Backend" /min cmd /d /c "cd /d "%BACKEND_DIR%" && call load-env.bat && mvn spring-boot:run >> "%BACKEND_LOG%" 2>&1"
) else (
  echo [LifeScale] 后端健康检查已通过，跳过重复启动。
)

call :WaitBackend 60
if errorlevel 1 exit /b 1

echo [LifeScale] 检查桌面端依赖...
pushd "%DESKTOP_DIR%" >nul
if not exist "node_modules" (
  echo [LifeScale] 未检测到 node_modules，开始执行 pnpm install --frozen-lockfile...
  echo.>> "%DESKTOP_LOG%"
  echo ===== %date% %time% 安装桌面端依赖 =====>> "%DESKTOP_LOG%"
  pnpm install --frozen-lockfile >> "%DESKTOP_LOG%" 2>&1
  if errorlevel 1 (
    popd >nul
    echo [错误] 桌面端依赖安装失败。最近日志：%DESKTOP_LOG%
    exit /b 1
  )
) else (
  echo [LifeScale] 已检测到 node_modules，跳过依赖安装。
)
popd >nul

echo [LifeScale] 启动 Tauri 桌面端开发模式...
echo.>> "%DESKTOP_LOG%"
echo ===== %date% %time% 启动桌面端 =====>> "%DESKTOP_LOG%"
start "LifeScale Desktop" /min cmd /d /c "cd /d "%DESKTOP_DIR%" && pnpm tauri dev >> "%DESKTOP_LOG%" 2>&1"

call :WaitVite 60
if errorlevel 1 exit /b 1

echo.
echo [LifeScale] 启动流程已提交。
echo [LifeScale] 后端健康检查：http://localhost:8080/api/health
echo [LifeScale] OpenAPI 文档：http://localhost:8080/swagger-ui.html
echo [LifeScale] Vite 预览地址：http://localhost:5173
echo [LifeScale] 日志目录：%LOG_DIR%
exit /b 0

REM ============================================================================
REM CleanupStaleBackend：启动前清理残留的全栈容器（抢占 8080 的元凶）
REM 只删容器，不删数据卷（保留 lifescale-cas-data 等）。
REM ============================================================================
:CleanupStaleBackend
for %%C in (lifescale-backend lifescale-nginx lifescale-pg) do (
  docker ps -a --format "{{.Names}}" ^| findstr /X "%%C" >nul 2>&1
  if not errorlevel 1 (
    echo [LifeScale] 发现残留容器 %%C，正在清理...
    docker rm -f %%C >nul 2>&1
  )
)
REM 同时清理可能残留的全栈 compose 网络（lifescale-net），避免下次冲突
docker network rm lifescale-net >nul 2>&1
exit /b 0

REM ============================================================================
REM CheckPort8080：检查 8080 端口是否被占用
REM - 无监听 → 通过（errorlevel 0）
REM - 被占用 → 报错并提示，让用户先用 stop.bat 清理（errorlevel 1）
REM ============================================================================
:CheckPort8080
powershell -NoProfile -ExecutionPolicy Bypass -Command "$conn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue; if ($conn) { $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue; $name = if ($proc) { $proc.ProcessName } else { '未知' }; Write-Host ('[错误] 端口 8080 已被占用：' + $name + '(PID ' + $conn.OwningProcess + ')。') -ForegroundColor Red; Write-Host '       请先运行 stop.bat 清理，或手动结束占用进程后重试。' -ForegroundColor Yellow; exit 1 } else { Write-Host '[LifeScale] 端口 8080 未被占用，可正常启动。'; exit 0 }"
exit /b %errorlevel%

:WaitContainer
set "CONTAINER=%~1"
set "LIMIT=%~2"
echo [LifeScale] 等待 %CONTAINER% 进入 healthy 状态...
for /L %%I in (1,1,%LIMIT%) do (
  set "HEALTH=unknown"
  for /f "usebackq delims=" %%S in (`docker inspect -f "{{.State.Health.Status}}" "%CONTAINER%" 2^>nul`) do set "HEALTH=%%S"
  if /I "!HEALTH!"=="healthy" (
    echo [LifeScale] %CONTAINER% 已就绪。
    exit /b 0
  )
  ping -n 3 127.0.0.1 >nul
)
echo [错误] %CONTAINER% 未在预期时间内变为 healthy。最近日志：%DOCKER_LOG%
exit /b 1

:CheckBackend
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-RestMethod -Uri 'http://localhost:8080/api/health' -TimeoutSec 2; if ($r.status -eq 'UP') { exit 0 } else { exit 1 } } catch { exit 1 }"
exit /b %errorlevel%

:WaitBackend
set "LIMIT=%~1"
echo [LifeScale] 等待后端健康检查通过...
for /L %%I in (1,1,%LIMIT%) do (
  call :CheckBackend
  if not errorlevel 1 (
    echo [LifeScale] 后端健康检查通过。
    exit /b 0
  )
  ping -n 3 127.0.0.1 >nul
)
echo [错误] 后端未在预期时间内通过健康检查。最近日志：%BACKEND_LOG%
exit /b 1

:CheckVite
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:5173' -TimeoutSec 2; if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { exit 0 } else { exit 1 } } catch { exit 1 }"
exit /b %errorlevel%

:WaitVite
set "LIMIT=%~1"
echo [LifeScale] 等待桌面端 Vite 服务可访问...
for /L %%I in (1,1,%LIMIT%) do (
  call :CheckVite
  if not errorlevel 1 (
    echo [LifeScale] 桌面端 Vite 服务已就绪。
    exit /b 0
  )
  ping -n 3 127.0.0.1 >nul
)
echo [错误] 桌面端 Vite 服务未在预期时间内可访问。最近日志：%DESKTOP_LOG%
exit /b 1
