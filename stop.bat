@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "ROOT=%~dp0"
set "DOCKER_DIR=%ROOT%docker"
set "LOG_DIR=%ROOT%logs"
set "DOCKER_LOG=%LOG_DIR%\docker.log"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo [LifeScale] 开始关闭本地开发链路...
echo [LifeScale] 关闭可能存在的 LifeScale 桌面进程...
for %%P in (lifescale-desktop.exe LifeScale.exe) do (
  taskkill /IM %%P /F >nul 2>&1
)

echo [LifeScale] 释放前端、桌面热更新、后端与依赖服务端口...
call :ReleasePorts

echo [LifeScale] 停止 Docker Compose 依赖服务（保留数据卷）...
docker info >nul 2>&1
if errorlevel 1 (
  echo [警告] Docker 当前不可用，已跳过 docker compose down。
) else (
  pushd "%DOCKER_DIR%" >nul
  REM 先停 local 开发依赖（docker-compose.yml，含 PG/Redis）
  docker compose down >> "%DOCKER_LOG%" 2>&1
  if errorlevel 1 (
    echo [警告] docker compose down（local）执行失败。最近日志：%DOCKER_LOG%
  ) else (
    echo [LifeScale] local 开发依赖（PG/Redis）已停止，数据卷已保留。
  )
  REM 再停全栈容器化编排（docker-compose.full.yml，含 backend/nginx）
  REM 防止残留 lifescale-backend 容器抢占 8080 端口导致下次 start.bat 失败
  if exist "docker-compose.full.yml" (
    docker compose -f docker-compose.full.yml down >> "%DOCKER_LOG%" 2>&1
    if errorlevel 1 (
      echo [警告] docker compose -f docker-compose.full.yml down 执行失败（可能未启用全栈编排）。
    ) else (
      echo [LifeScale] 全栈容器化编排（含 backend/nginx）已停止，数据卷已保留。
    )
  )
  popd >nul

  REM 兜底清理：即使 compose down 漏掉，也强制删除残留 backend 容器
  call :CleanupStaleBackend
)

echo [LifeScale] 再次确认并清理 LifeScale 约定端口...
call :ReleasePorts
call :ShowPortStatus

echo [LifeScale] 关闭完成，可重新运行 start.bat。
exit /b 0

REM ============================================================================
REM CleanupStaleBackend：兜底清理残留的全栈 backend 容器（抢占 8080 的元凶）
REM docker-compose.full.yml 起的 lifescale-backend 容器若残留，会与 mvn 后端抢 8080 端口。
REM 这里不强删数据卷（保留 lifescale-cas-data 等），只删容器。
REM ============================================================================
:CleanupStaleBackend
for %%C in (lifescale-backend lifescale-nginx lifescale-pg) do (
  docker ps -a --format "{{.Names}}" | findstr /X "%%C" >nul 2>&1
  if not errorlevel 1 (
    echo [LifeScale] 发现残留容器 %%C，正在清理...
    docker rm -f %%C >nul 2>&1
    if not errorlevel 1 (
      echo [LifeScale] 已清理残留容器 %%C。
    )
  )
)
exit /b 0

:ReleasePorts
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ports = @(5173, 5174, 8080, 15432, 16379); $skip = @('com.docker.backend', 'wslrelay', 'wslhost', 'docker-proxy', 'Docker Desktop'); foreach ($port in $ports) { $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue; foreach ($connection in $connections) { $ownerId = $connection.OwningProcess; $process = Get-Process -Id $ownerId -ErrorAction SilentlyContinue; if ($process) { if ($skip -contains $process.ProcessName) { Write-Host ('端口 {0} 当前由 {1}({2}) 占用，交给 Docker Compose 停止。' -f $port, $process.ProcessName, $ownerId); } else { Stop-Process -Id $ownerId -Force -ErrorAction SilentlyContinue; Write-Host ('已释放端口 {0}：{1}({2})' -f $port, $process.ProcessName, $ownerId); } } } }"
exit /b 0

:ShowPortStatus
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ports = @(5173, 5174, 8080, 15432, 16379); $active = Get-NetTCPConnection -LocalPort $ports -State Listen -ErrorAction SilentlyContinue; if (-not $active) { Write-Host '端口检查通过：5173、5174、8080、15432、16379 均未监听。'; } else { foreach ($connection in $active) { $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue; $name = if ($process) { $process.ProcessName } else { '未知进程' }; Write-Host ('仍有监听：端口 {0}，进程 {1}({2})。' -f $connection.LocalPort, $name, $connection.OwningProcess); } }"
exit /b 0
