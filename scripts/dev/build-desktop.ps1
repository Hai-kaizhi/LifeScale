# ============================================================================
# build-desktop.ps1 —— LifeScale 桌面端 Windows 打包脚本（测试版 / 正式版）
# ============================================================================
# 用法（建议通过 build-desktop.bat 调用，或直接用 powershell 运行）：
#   .\build-desktop.ps1 -Version 0.2.0 -Channel beta        # 测试版（NSIS exe）
#   .\build-desktop.ps1 -Version 0.2.0 -Channel release      # 正式版（NSIS exe）
#   .\build-desktop.ps1 -Version 0.2.0 -Channel release -IncludeMsi   # 正式版连 msi 一起打
#
# 产物归档到：<仓库根>/dist/release/desktop/<渠道>/（已被 .gitignore 忽略，不入 git）
#   测试版 → lifescale-<版本>-beta-windows-x64-setup.exe
#   正式版 → lifescale-<版本>-windows-x64-setup.exe（+可选 .msi）
# 同时生成 BUILD-INFO.txt。
#
# 签名说明：当前 Windows 安装包未做代码签名，首次安装会被 SmartScreen 拦截，
# 用户需手动「更多信息 → 仍要运行」。接入代码签名见 docs/deployment/客户端打包指南.md。
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,                       # 版本号，如 0.2.0
    [Parameter(Mandatory = $true)]
    [ValidateSet("beta", "release")]
    [string]$Channel,                       # beta（测试版）/ release（正式版）
    [switch]$IncludeMsi = $false            # 正式版是否同时产出 msi（默认只产 NSIS exe，更快）
)

# ---- 路径与常量 ----
$ErrorActionPreference = "Stop"
$ROOT    = Resolve-Path "$PSScriptRoot\..\.."          # 仓库根
$DESKTOP = Join-Path $ROOT "desktop"                    # desktop 源码目录
$TAURI_DIR  = Join-Path $DESKTOP "src-tauri"
# 产物输出到仓库内 dist/release/（已被 .gitignore 忽略，不入 git）
$RELEASE_DIR = Join-Path $ROOT "dist\release\desktop\$Channel"

# 渠道 → 版本后缀 / 产物名前缀
$IsBeta = ($Channel -eq "beta")
# 统一使用 tauri.conf.json（无 beta/正式多配置文件；通过 productName 在 BUILD-INFO 区分）
$ConfigPath = Join-Path $TAURI_DIR "tauri.conf.json"
$EffectiveVersion = if ($IsBeta) { "$Version-beta" } else { $Version }
$ProductLabel = if ($IsBeta) { "LifeScale 测试版" } else { "LifeScale" }

# ---- 工具函数 ----
function Write-Step($msg) { Write-Host "`n[step] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Write-Die($msg)  { Write-Host "  [ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host " LifeScale Desktop (Windows) 打包" -ForegroundColor Yellow
Write-Host "   版本: $EffectiveVersion  渠道: $Channel" -ForegroundColor Yellow
Write-Host "   配置文件: tauri.conf.json" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# ---- 1. 环境检查 ----
Write-Step "检查构建环境"
# 把常见工具目录加入本次会话 PATH（Git Bash 的 PATH 不一定带进 PowerShell 子进程）
$extraPaths = @(
    "$env:USERPROFILE\.cargo\bin",
    "$env:APPDATA\npm", "$env:APPDATA\pnpm",
    "$env:LOCALAPPDATA\pnpm",
    "$env:USERPROFILE\AppData\Roaming\npm"
)
foreach ($p in $extraPaths) { if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) { $env:PATH = "$env:PATH;$p" } }

Push-Location $DESKTOP
$pnpmOk = (& pnpm --version 2>$null)
if (-not $pnpmOk) { Write-Die "pnpm 不可用，请先安装 pnpm（npm i -g pnpm）并确保其在 PATH" }
Write-Ok "pnpm $pnpmOk"
$cargoOk = (& cargo --version 2>$null)
if (-not $cargoOk) { Write-Die "cargo(Rust) 不可用，请先安装 Rust toolchain（含 MSVC）" }
Write-Ok $cargoOk

# ---- 2. 注入版本号到 tauri.conf.json ----
# 逐行处理：找到含 "version": 的行，用 StartsWith 定位、字符串方法替换值，
# 避免 ConvertTo-Json 重排格式 + Set-Content 的 BOM 问题 + -replace 正则不稳。
Write-Step "写入版本号到 tauri.conf.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$raw = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$lineSep = "`r`n"
if (-not $raw.Contains("`r`n")) { $lineSep = "`n" }
$rawLines = $raw -split "`r?`n"
$replaced = $false
for ($i = 0; $i -lt $rawLines.Count; $i++) {
    $t = $rawLines[$i].TrimStart()
    if ($t.StartsWith('"version"')) {
        # 行格式固定：  "version": "0.1.0"  → 替换引号内的值
        $idx = $rawLines[$i].IndexOf(':')
        if ($idx -ge 0) {
            $prefix = $rawLines[$i].Substring(0, $idx + 1)
            $rawLines[$i] = "$prefix `"$EffectiveVersion`","
            $replaced = $true
            break
        }
    }
}
if (-not $replaced) { Write-Die "未在 tauri.conf.json 找到 version 字段" }
$updated = [string]::Join($lineSep, $rawLines)
[System.IO.File]::WriteAllText($ConfigPath, $updated, $utf8NoBom)
Write-Ok "version → $EffectiveVersion"

# ---- 3. 决定 bundle targets ----
# 测试版只产 nsis（快）；正式版产 nsis，可选 msi
$bundles = if ($IncludeMsi -and -not $IsBeta) { "nsis,msi" } else { "nsis" }
Write-Step "bundle targets: $bundles"

try {
    # pnpm/cargo/tauri 会把进度/警告写到 stderr，Stop 模式会误判为错误，调用时临时放宽
    # ---- 4. 构建 ----
    Write-Step "pnpm tauri build（首次或依赖变更时可能耗时 5-15 分钟）"
    $ErrorActionPreference = "Continue"
    & pnpm tauri build --bundles $bundles 2>&1 |
        Select-String -Pattern "Built application|Finished|bundle|error|Error|warning:" |
        ForEach-Object { Write-Host "  $_" }
    $ec = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($ec -ne 0) { Write-Die "pnpm tauri build 失败" }

    # ---- 5. 收集并归档产物 ----
    $bundleBase = Join-Path $TAURI_DIR "target\release\bundle"
    $collected = @()

    # NSIS exe
    $nsisDir = Join-Path $bundleBase "nsis"
    if (Test-Path $nsisDir) {
        $exe = Get-ChildItem $nsisDir -Filter "*-setup.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($exe) { $collected += $exe.FullName }
    }
    # MSI
    if ($IncludeMsi -and -not $IsBeta) {
        $msiDir = Join-Path $bundleBase "msi"
        if (Test-Path $msiDir) {
            $msi = Get-ChildItem $msiDir -Filter "*.msi" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($msi) { $collected += $msi.FullName }
        }
    }

    if ($collected.Count -eq 0) { Write-Die "未找到任何构建产物" }

    Write-Step "归档产物到 $RELEASE_DIR"
    New-Item -ItemType Directory -Force -Path $RELEASE_DIR | Out-Null
    $archivedNames = @()
    foreach ($src in $collected) {
        $sizeMB = [math]::Round((Get-Item $src).Length / 1MB, 1)
        # 规范化归档文件名（去掉中文/空格，统一命名）
        $ext = [System.IO.Path]::GetExtension($src)
        $archiveName = if ($IsBeta) {
            "lifescale-$Version-beta-windows-x64-setup$ext"
        } else {
            "lifescale-$Version-windows-x64-setup$ext"
        }
        $archivePath = Join-Path $RELEASE_DIR $archiveName
        Copy-Item -Path $src -Destination $archivePath -Force
        Write-Ok "$archiveName ($sizeMB MB)  ←  $(Split-Path $src -Leaf)"
        $archivedNames += "$archiveName ($sizeMB MB)"
    }

    # ---- 6. 生成 BUILD-INFO.txt ----
    $commitHash = "unknown"
    try { $commitHash = (git -C $ROOT rev-parse --short HEAD 2>$null) } catch { }

    $info = @"
LifeScale Desktop (Windows) 构建信息
============================================================
版本号 (version)     : $EffectiveVersion
渠道 (channel)       : $Channel
productName          : $ProductLabel
identifier           : com.lifescale.desktop
bundle targets       : $bundles
签名状态             : 未签名（首次安装会被 SmartScreen 拦截，见下方说明）
构建时间             : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
git commit           : $commitHash
构建机器             : $env:COMPUTERNAME
归档文件             :
$(($archivedNames | ForEach-Object { "  - $_" }) -join "`n")

注意：
- 本安装包未做代码签名。用户首次运行安装包时，Windows SmartScreen 会弹出
  「Windows 已保护你的电脑」，需点击「更多信息」→「仍要运行」。
- 自用/熟人安装无碍；正式对外分发前建议接入代码签名证书（见 docs/deployment/客户端打包指南.md）。
"@
    $infoPath = Join-Path $RELEASE_DIR "BUILD-INFO.txt"
    [System.IO.File]::WriteAllText($infoPath, $info, $utf8NoBom)
    Write-Ok "已生成 BUILD-INFO.txt"

    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host " 打包完成 ✓" -ForegroundColor Green
    $archivedNames | ForEach-Object { Write-Host "  产物: $_" -ForegroundColor Green }
    Write-Host "  信息: $infoPath" -ForegroundColor Green
    Write-Host "================================================`n" -ForegroundColor Green

} finally {
    Pop-Location -ErrorAction SilentlyContinue
}
