# ============================================================================
# gen-icons.ps1 —— LifeScale 应用图标一键重新生成（移动端 + 桌面端）
# ============================================================================
# 用法（建议通过 gen-icons.bat 调用，或直接用 powershell 运行）：
#   .\gen-icons.ps1                  # 重新生成移动端 + 桌面端全套图标
#   .\gen-icons.ps1 -AndroidOnly     # 只生成移动端
#   .\gen-icons.ps1 -DesktopOnly     # 只生成桌面端
#
# 前置：源图已就位（见下方路径）。修改源图后跑本脚本即可刷新所有尺寸的图标。
#   移动端正式版源图: mobile/assets/icons/brand/app_icon_source_1024.png
#   移动端测试版源图: mobile/assets/icons/brand/app_icon_source_1024_beta.png
#   桌面端源图      : desktop/src-tauri/app-icon.png
#
# 移动端依赖 flutter_launcher_icons（pubspec dev_dependencies）：
#   - 配置文件：mobile/flutter_launcher_icons-prod.yaml / -beta.yaml
#   - 生成 prod/beta 两套 mipmap 图标（main/prod/beta 三套 res）
# ============================================================================

param(
    [switch]$AndroidOnly = $false,
    [switch]$DesktopOnly = $false
)

$ErrorActionPreference = "Stop"
$ROOT    = Resolve-Path "$PSScriptRoot\..\.."          # lifescale/ 仓库根
$MOBILE  = Join-Path $ROOT "mobile"
$DESKTOP = Join-Path $ROOT "desktop"
$RunAll = (-not $AndroidOnly -and -not $DesktopOnly)

function Write-Step($msg) { Write-Host "`n[step] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Write-Die($msg)  { Write-Host "  [ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host " LifeScale 图标重新生成" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# 把常见工具目录加入本次会话 PATH（Git Bash 的 PATH 不一定带进 PowerShell 子进程）
$extraPaths = @(
    "$env:USERPROFILE\.cargo\bin", "$env:APPDATA\npm", "$env:APPDATA\pnpm",
    "$env:LOCALAPPDATA\pnpm", "E:\flutter\bin", "C:\flutter\bin", "C:\src\flutter\bin",
    "$env:USERPROFILE\flutter\bin", "D:\flutter\bin"
)
foreach ($p in $extraPaths) { if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) { $env:PATH = "$env:PATH;$p" } }

# ---- 移动端 ----
if ($RunAll -or $AndroidOnly) {
    Write-Step "移动端：flutter_launcher_icons（生成 prod + beta 全尺寸图标）"
    $prodSrc = Join-Path $MOBILE "assets\icons\brand\app_icon_source_1024.png"
    $betaSrc = Join-Path $MOBILE "assets\icons\brand\app_icon_source_1024_beta.png"
    if (-not (Test-Path $prodSrc)) { Write-Die "缺少源图: $prodSrc" }
    if (-not (Test-Path $betaSrc)) { Write-Die "缺少源图: $betaSrc" }

    Push-Location $MOBILE
    try {
        # flutter/dart 会把普通信息写到 stderr，Stop 模式会误判为错误，调用时临时放宽
        $ErrorActionPreference = "Continue"
        & flutter pub get 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Host "  $_" }
        # 不带 -f：自动发现 flutter_launcher_icons-prod.yaml 和 -beta.yaml
        & dart run flutter_launcher_icons 2>&1 |
            Select-String -Pattern "Flavor|Creating|Overwriting|Successfully|ERROR|No platform" |
            ForEach-Object { Write-Host "  $_" }
        $ec = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        if ($ec -ne 0) { Write-Die "移动端图标生成失败" }
    } finally { Pop-Location }
    Write-Ok "移动端图标已生成（main/prod/beta 三套 mipmap）"
}

# ---- 桌面端 ----
if ($RunAll -or $DesktopOnly) {
    Write-Step "桌面端：tauri icon（重新生成 src-tauri/icons/ 全套）"
    $deskSrc = Join-Path $DESKTOP "src-tauri\app-icon.png"
    if (-not (Test-Path $deskSrc)) { Write-Die "缺少源图: $deskSrc" }

    Push-Location $DESKTOP
    try {
        $ErrorActionPreference = "Continue"
        & pnpm tauri icon src-tauri/app-icon.png 2>&1 |
            Select-String -Pattern "Creating|Finished|error|Error" |
            ForEach-Object { Write-Host "  $_" }
        $ec = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        if ($ec -ne 0) { Write-Die "桌面端图标生成失败" }
        # tauri icon 会顺带生成 android/ios 子目录图标，桌面端项目用不到，清理掉避免冗余
        $iconsDir = Join-Path $DESKTOP "src-tauri\icons"
        foreach ($d in @("android", "ios")) {
            $sub = Join-Path $iconsDir $d
            if (Test-Path $sub) { Remove-Item -Recurse -Force $sub }
        }
        $extra = Join-Path $iconsDir "64x64.png"
        if (Test-Path $extra) { Remove-Item -Force $extra }
    } finally { Pop-Location }
    Write-Ok "桌面端图标已生成（icon.ico/icns/png/Square* 全套）"
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host " 图标重新生成完成 ✓" -ForegroundColor Green
Write-Host " 提示：源图更新后跑本脚本即可刷新所有尺寸。" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Green
