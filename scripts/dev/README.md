# scripts/dev —— 开发与构建脚本（开源）

本目录是**开源**的通用开发/打包脚本，公众 clone 后可直接使用。

## 内容

| 脚本 | 用途 |
|---|---|
| `build-desktop.ps1` / `.bat` | 桌面端 Windows 安装包打包（NSIS exe） |
| `build-android.ps1` / `.bat` | 移动端 Android APK 打包 |
| `gen-icons.ps1` / `.bat` | 桌面端应用图标重新生成 |

## 用法

详见 [`../../docs/deployment/客户端打包指南.md`](../../docs/deployment/客户端打包指南.md)。

打包产物输出到仓库外的 `../workspace/release/`（不入 git）。

## 设计说明

- 本目录脚本**不含任何敏感信息**（无真实密钥/服务器/签名路径），可安全公开。
- 测试/生产环境的运维脚本（含敏感信息）不放这里，见相邻的 `../test/` 和 `../prod/`。
