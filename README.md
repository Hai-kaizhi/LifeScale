# LifeScale

> 本地优先（Local-First）的 Markdown Vault 个人管理应用。所有数据保存在你的设备本地，无需任何后端服务器，开箱即用。

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

## 功能特性

- **纯本地**：所有数据存在本地 SQLite + 本地 Markdown 文件，无需后端、无需联网、无需账号
- **桌面端**（Tauri + React）：今日计划、回看日历、笔记知识库、复盘，Markdown 所见即所得编辑
- **移动端**（Flutter）：今日、回看、笔记、复盘，本地优先的随身记录
- **Markdown Vault**：以本地 Markdown 文件为存储载体，每日结构化数据可沉淀为零注释的干净归档
- **附件缓存**：图片按内容哈希（SHA-256）缓存在本地数据目录

> 本仓库是 **开源本地版**：不含任何后端、云同步、数据库服务端或部署编排。
> 每台设备独立运行、独立存储；如需多端云同步，请关注项目的完整版本。

## 技术栈

| 模块 | 技术 | 包管理 |
| --- | --- | --- |
| 桌面端 | Tauri 2 + React 19 + TypeScript + Vite + Ant Design | pnpm |
| 移动端 | Flutter + Riverpod + go_router | pub |
| 本地数据库 | SQLite（桌面 rusqlite / 移动 sqflite） | - |

## 目录结构

```text
desktop/    Tauri 2 + React 19 桌面端
mobile/     Flutter 移动端
docs/       技术文档（架构、数据模型、打包指南）
scripts/    客户端打包/图标生成脚本（dev）
```

## 快速开始

### 前置要求

- 桌面端：Node 20+、pnpm 10、Rust 工具链（Tauri 2 依赖）
- 移动端：Flutter SDK

### 桌面端

```bash
cd desktop
pnpm install
pnpm tauri dev      # 启动桌面应用（首次会编译 Rust，较慢）
# 或 pnpm dev        # 仅 web 预览（无 Tauri 本地文件桥，文件写入为内存模拟）
```

### 移动端

```bash
cd mobile
flutter pub get
flutter run          # 连接模拟器或真机
```

> 移动端默认使用本地模式：打开即用，无登录、无同步流程。

### 数据存储位置

- **桌面端**：系统应用数据目录下的 `Vault/`（Markdown 文件 + `lifescale.db` 业务库）
- **移动端**：应用沙盒内的 `.lifescale/`（Markdown 文件 + `lifescale.db` 业务库）

数据完全本地化，卸载应用即清除。建议定期手动备份数据目录。

### 验证

```bash
cd desktop && pnpm test:run       # 桌面端 vitest
cd mobile  && flutter test        # 移动端 dart test
```

## 客户端打包

见 [`docs/deployment/客户端打包指南.md`](./docs/deployment/客户端打包指南.md)（桌面端 Windows 安装包、移动端 APK）。

## 参与贡献

欢迎贡献！请先阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

发现安全漏洞请勿开 public issue，请按 [SECURITY.md](./SECURITY.md) 流程私密报告。

## 版本记录

见 [CHANGELOG.md](./CHANGELOG.md)。

## 远程仓库

本项目同时在两个平台开源，内容完全一致，按你的访问偏好选择：

- **Gitee**（国内访问快）：https://gitee.com/XiaoZhi-paperfly/life-scale
- **GitHub**（国际社区）：https://github.com/Hai-kaizhi/LifeScale

## 许可证

本项目基于 [Apache License 2.0](./LICENSE) 开源。
