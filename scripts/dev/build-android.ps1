# ============================================================================
# build-android.ps1 —— LifeScale 移动端 Android 打包脚本（测试版 / 正式版）
# ============================================================================
# 用法（建议通过 build-android.bat 调用，或直接用 powershell 运行）：
#   .\build-android.ps1 -Version 0.2.0 -Channel beta        # 测试版（beta flavor）
#   .\build-android.ps1 -Version 0.2.0 -Channel release      # 正式版（prod flavor）
#   .\build-android.ps1 -Version 0.2.0 -Channel beta -BuildNumber 5   # 指定构建号
#   .\build-android.ps1 -Version 0.2.0 -Channel beta -InstallToPhone   # 打包后安装到已连接真机
#
# 产物归档到：<仓库根>/dist/release/android/<渠道>/（已被 .gitignore 忽略，不入 git）
#   测试版 → lifescale-<版本>-beta-android.apk
#   正式版 → lifescale-<版本>-android.apk
# 同时生成 BUILD-INFO.txt（版本/时间/git commit/渠道/签名状态）。
#
# 签名说明：当前 release 包使用 debug 签名（仅限内测/自用安装），
# 上架应用商店前需换成正式 keystore（见 docs/deployment/客户端打包指南.md）。
#
# Flavor 架构说明：
#   mobile/android/app/build.gradle.kts 配置了 productFlavors：
#     - prod：正式版，默认 applicationId，无后缀
#     - beta：测试版，applicationId 追加 .beta（可与正式版同机共存），版本名加 -beta
#   两套图标/应用名物理隔离。渠道(beta/release) → Gradle flavor 映射见下方。
#
# 注：LifeScale 为纯本地应用，无后端，故无后端地址注入 / mock 开关等参数。
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,                       # 版本号，如 0.2.0
    [Parameter(Mandatory = $true)]
    [ValidateSet("beta", "release")]
    [string]$Channel,                       # beta（测试版）/ release（正式版）
    [int]$BuildNumber = 0,                  # versionCode 用的构建号；0 = 自动用当前日期 yyyyMMdd
    [switch]$InstallToPhone                 # 打包后自动安装到已连接的真机（adb install）
)

# ---- 路径与常量 ----
$ErrorActionPreference = "Stop"
$ROOT    = Resolve-Path "$PSScriptRoot\..\.."          # 仓库根
$MOBILE  = Join-Path $ROOT "mobile"                     # mobile 源码目录
# 产物输出到仓库内 dist/release/（已被 .gitignore 忽略，不入 git）
$RELEASE_DIR = Join-Path $ROOT "dist\release\android\$Channel"
$PUBSPEC = Join-Path $MOBILE "pubspec.yaml"

# flavor 映射：渠道 → Gradle flavor
$Flavor = if ($Channel -eq "beta") { "beta" } else { "prod" }

# 自动构建号（未指定则用日期）
if ($BuildNumber -le 0) {
    $BuildNumber = [int](Get-Date -Format "yyyyMMdd")
}

# ---- 工具函数 ----
function Write-Step($msg) { Write-Host "`n[step] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [ok] $msg" -ForegroundColor Green }
function Write-Die($msg)  { Write-Host "  [ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host " LifeScale Android 打包" -ForegroundColor Yellow
Write-Host "   版本: $Version  渠道: $Channel (flavor=$Flavor)" -ForegroundColor Yellow
Write-Host "   构建号(versionCode): $BuildNumber" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# ---- 1. 环境检查 ----
Write-Step "检查 flutter 环境"
# 探测 flutter：先 PATH，再常见安装位置（Git Bash 的 PATH 不一定带进 PowerShell 子进程）
function Find-Flutter {
    $f = Get-Command flutter -ErrorAction SilentlyContinue
    if ($f) { return $f.Source }
    $candidates = @(
        "E:\flutter\bin\flutter.bat", "C:\flutter\bin\flutter.bat", "C:\src\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat", "D:\flutter\bin\flutter.bat"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}
$flutterExe = Find-Flutter
if (-not $flutterExe) {
    Write-Die "flutter 不可用（PATH 找不到，常见安装位置也没有）。请确认 Flutter SDK 已安装，或把 flutter 加入 PATH 后重试。"
}
# 把 flutter 所在目录加入本次会话 PATH，后续直接用 flutter
$env:PATH = "$env:PATH;$(Split-Path $flutterExe)"
$flutterVersion = & flutter --version 2>&1 | Select-Object -First 1
Write-Ok $flutterVersion

# ---- 2. 注入版本号到 pubspec.yaml（version: <x.y.z>+<buildNumber>）----
# 用 .NET API 精确读写（UTF-8 无 BOM），逐行替换 version 行，避开 -replace 正则在某些
# PowerShell 环境下 ^ 锚点失效的坑。
Write-Step "写入版本号到 pubspec.yaml"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$originalContent = [System.IO.File]::ReadAllText($PUBSPEC, [System.Text.Encoding]::UTF8)
$newVersionLine = "version: $Version+$BuildNumber"

# 逐行处理：找到以 "version:" 开头（允许前导空白）的行，整行替换。
# 用 TrimStart + StartsWith 纯字符串方法，不依赖正则 ^ 锚点（某些 PowerShell 环境下不稳）。
$lineSep = "`r`n"
if (-not $originalContent.Contains("`r`n")) { $lineSep = "`n" }
$rawLines = $originalContent -split "`r?`n"
$replaced = $false
for ($i = 0; $i -lt $rawLines.Count; $i++) {
    if ($rawLines[$i].TrimStart().StartsWith("version:")) {
        $rawLines[$i] = $newVersionLine
        $replaced = $true
        break
    }
}
if (-not $replaced) { Write-Die "未在 pubspec.yaml 找到 version: 行" }
$updatedContent = [string]::Join($lineSep, $rawLines)
[System.IO.File]::WriteAllText($PUBSPEC, $updatedContent, $utf8NoBom)
Write-Ok "pubspec.yaml version → $newVersionLine"

try {
    # flutter/dart 会把普通信息写到 stderr，Stop 模式会误判为错误，调用时临时放宽
    # ---- 3. 拉依赖 ----
    Write-Step "flutter pub get"
    Push-Location $MOBILE
    $ErrorActionPreference = "Continue"
    & flutter pub get 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host "  $_" }
    $ec = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($ec -ne 0) { Write-Die "flutter pub get 失败" }
    Write-Ok "依赖就绪"

    # ---- 4. 构建 release APK（按 flavor）----
    Write-Step "构建 $Flavor flavor release APK（可能耗时 2-5 分钟）"
    $ErrorActionPreference = "Continue"
    & flutter build apk --flavor $Flavor --release 2>&1 |
        Select-String -Pattern "Built|error|Error|失败|Built build" |
        ForEach-Object { Write-Host "  $_" }
    $ec = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($ec -ne 0) { Write-Die "flutter build apk 失败" }

    $apkPath = Join-Path $MOBILE "build\app\outputs\flutter-apk\app-$Flavor-release.apk"
    if (-not (Test-Path $apkPath)) { Write-Die "未找到构建产物: $apkPath" }
    $apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 1)
    Write-Ok "构建成功: $apkPath ($apkSize MB)"

    # ---- 5. 归档到 release 目录 ----
    Write-Step "归档产物到 $RELEASE_DIR"
    New-Item -ItemType Directory -Force -Path $RELEASE_DIR | Out-Null
    $archiveName = if ($Channel -eq "beta") {
        "lifescale-$Version-beta-android.apk"
    } else {
        "lifescale-$Version-android.apk"
    }
    $archivePath = Join-Path $RELEASE_DIR $archiveName
    Copy-Item -Path $apkPath -Destination $archivePath -Force
    Write-Ok "已归档: $archivePath ($apkSize MB)"

    # ---- 6. 安装到已连接的真机（可选，-InstallToPhone）----
    if ($InstallToPhone) {
        Write-Step "安装到已连接的真机"
        # 探测 adb：先 PATH，再 Android SDK 常见位置
        function Find-Adb {
            $a = Get-Command adb -ErrorAction SilentlyContinue
            if ($a) { return $a.Source }
            $cands = @(
                "$env:ANDROID_HOME\platform-tools\adb.exe",
                "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
                "E:\AndroidSdk\platform-tools\adb.exe",
                "C:\AndroidSdk\platform-tools\adb.exe",
                "D:\AndroidSdk\platform-tools\adb.exe"
            )
            foreach ($c in $cands) { if (Test-Path $c) { return $c } }
            return $null
        }
        $adbExe = Find-Adb
        if (-not $adbExe) { Write-Die "未找到 adb，请确认 Android SDK platform-tools 已安装，或设置 ANDROID_HOME 环境变量" }
        Write-Ok "adb: $adbExe"

        $devices = & $adbExe devices | Select-String -Pattern "\bdevice$" -CaseSensitive:$false
        $deviceCount = ($devices | Measure-Object).Count
        if ($deviceCount -eq 0) {
            Write-Host "  [WARN] 未检测到已连接的设备，跳过安装。请确认手机已开启 USB 调试并连接。" -ForegroundColor Yellow
        } else {
            Write-Ok "检测到 $deviceCount 台设备"
            # 先卸载同包名的旧版本（避免签名/版本号冲突导致 INSTALL_FAILED），再安装新包
            # beta flavor 的 applicationId 追加 .beta 后缀，可与正式版共存
            $appId = "com.lifescale.mobile.lifescale_mobile$(if ($Channel -eq 'beta') { '.beta' })"
            & $adbExe uninstall $appId 2>&1 | Out-Null
            $installOut = & $adbExe install -r $archivePath 2>&1
            $installOk = $installOut | Select-String -Pattern "Success" -CaseSensitive:$false
            if ($installOk) {
                Write-Ok "已安装: $archiveName → $appId"
            } else {
                Write-Host "  [安装输出] $installOut" -ForegroundColor DarkGray
                Write-Die "安装失败，请查看上方输出"
            }
        }
    }

    # ---- 7. 生成 BUILD-INFO.txt ----
    $commitHash = "unknown"
    try { $commitHash = (git -C $ROOT rev-parse --short HEAD 2>$null) } catch { }

    $info = @"
LifeScale Android 构建信息
============================================================
版本号 (versionName) : $Version$(if ($Channel -eq "beta") { "-beta" })
构建号 (versionCode) : $BuildNumber
渠道 (channel)       : $Channel
Gradle flavor        : $Flavor
Application ID       : com.lifescale.mobile.lifescale_mobile$(if ($Channel -eq "beta") { ".beta" })
应用显示名           : $(if ($Channel -eq "beta") { "LifeScale 测试版" } else { "LifeScale" })
签名状态             : DEBUG 签名（仅限内测/自用，未达上架要求）
构建时间             : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
git commit           : $commitHash
构建机器             : $env:COMPUTERNAME
源 APK 路径          : mobile\build\app\outputs\flutter-apk\app-$Flavor-release.apk
归档文件名           : $archiveName

注意：
- 当前 release 包使用 debug 签名，安装时部分手机需开启「允许未知来源应用」。
- 上架应用商店前必须换成正式 keystore（见 docs/deployment/客户端打包指南.md）。
"@
    $infoPath = Join-Path $RELEASE_DIR "BUILD-INFO.txt"
    [System.IO.File]::WriteAllText($infoPath, $info, $utf8NoBom)
    Write-Ok "已生成 BUILD-INFO.txt"

    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host " 打包完成 ✓" -ForegroundColor Green
    Write-Host "  产物: $archivePath" -ForegroundColor Green
    Write-Host "  信息: $infoPath" -ForegroundColor Green
    Write-Host "================================================`n" -ForegroundColor Green

} finally {
    Pop-Location -ErrorAction SilentlyContinue
    Write-Host "[note] pubspec.yaml 的版本号已被改为 $Version+$BuildNumber（保留，便于追溯；下次打包会再次覆盖）。" -ForegroundColor DarkGray
}
