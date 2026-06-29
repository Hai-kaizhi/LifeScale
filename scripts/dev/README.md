# scripts/dev —— 开发与打包脚本

本目录是通用开发/打包脚本，clone 后可直接使用。

## 内容

| 脚本 | 用途 |
|---|---|
| `build-desktop.ps1` / `.bat` | 桌面端 Windows 安装包打包（NSIS exe） |
| `build-android.ps1` / `.bat` | 移动端 Android APK 打包 |
| `gen-icons.ps1` / `.bat` | 桌面端应用图标重新生成 |

## 用法

详见 [`../../docs/deployment/客户端打包指南.md`](../../docs/deployment/客户端打包指南.md)。

打包产物输出到仓库内的 `../../dist/release/`（已被 `.gitignore` 忽略，不入 git）。

## 设计说明

- 本目录脚本**不含任何敏感信息**（无密钥/证书/服务器地址），可安全公开。
- LifeScale 是纯本地应用（无后端、无服务端），故打包脚本只负责客户端构建与归档，无部署/环境注入逻辑。
