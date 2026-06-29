# 贡献指南

感谢你对 LifeScale 的关注！欢迎通过以下方式参与贡献。

## 报告问题

- 在 Gitee 或 GitHub 仓库提交 Issue（bug 报告或功能建议）
- 提交前请先搜索是否已有相同 Issue
- Bug 报告请包含：复现步骤、期望行为、实际行为、环境信息（操作系统、桌面端/移动端版本）

## 提交代码

1. Fork 本仓库
2. 创建分支：`git checkout -b feature/your-feature` 或 `fix/your-fix`
3. 遵循现有代码风格（各端有自己的 lint 规则）
4. 提交信息使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：
   ```
   feat(scope): 简短描述
   fix(scope): 简短描述
   docs(scope): 简短描述
   refactor(scope): 简短描述
   perf(scope): 简短描述
   chore(scope): 简短描述
   ```
   scope 建议：`daily` / `vault` / `notes` / `review` / `attachment` / `build` 等
5. 如有需要，补充或更新测试
6. 提交 Pull Request，描述改动内容与动机

## 本地开发环境

本项目是**纯本地应用**，无后端、无数据库服务端、无网络依赖，开箱即用。

### 前置依赖

- 桌面端：Node 20+、pnpm 10、Rust 工具链（Tauri 2 依赖）
- 移动端：Flutter SDK

### 启动开发

```bash
# 桌面端
cd desktop && pnpm install && pnpm tauri dev

# 移动端
cd mobile && flutter pub get && flutter run
```

无需任何环境变量配置，无需 Docker，无需外部服务。

## 开发约定

- **本地数据库改动**：本项目使用本地 SQLite（桌面 rusqlite / 移动 sqflite）存储结构化业务数据（`ls_*` 表）。若修改本地表结构，须同步更新 [`docs/database/schema.sql`](./docs/database/schema.sql) 及两端实现。
- **两端共享数据模型**（Daily 实体 / 笔记 / 复盘）：确认桌面端与移动端同步修改，保持数据格式一致。
- **提交前运行测试**：
  ```bash
  cd desktop  && pnpm test:run       # 桌面端 vitest（一次性，非 watch）
  cd mobile   && flutter test        # 移动端 dart test
  ```
- **不提交敏感信息**：用户数据、构建产物均已在 `.gitignore` 中忽略，请勿 `git add -f`

## 提交红线

- ❌ 不得提交用户数据、构建产物
- ✅ 一个提交只做一件事，subject 用中文或英文简明描述
- ✅ 提交前跑相关端的测试

## 安全漏洞

请勿通过公开 Issue 报告安全漏洞。请按 [SECURITY.md](./SECURITY.md) 流程私密报告。
