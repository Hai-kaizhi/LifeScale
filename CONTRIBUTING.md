# 贡献指南

感谢你对 LifeScale 的关注！欢迎通过以下方式参与贡献。

## 报告问题

- 在 Gitee 或 GitHub 仓库提交 Issue（bug 报告或功能建议）
- 提交前请先搜索是否已有相同 Issue
- Bug 报告请包含：复现步骤、期望行为、实际行为、环境信息（操作系统、桌面端/移动端版本、后端版本）

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
   scope 建议：`auth` / `sync` / `daily` / `vault` / `attachment` / `build` / `deploy` 等
5. 如有需要，补充或更新测试
6. 提交 Pull Request，描述改动内容与动机

## 开发约定

- **数据库改动**：新建 Flyway 迁移文件 `V<n>__*.sql`，不修改已执行迁移（已执行的迁移是不可变契约）
- **三端共享协议**（同步 / 鉴权 / Daily 实体）：确认三端（backend / desktop / mobile）同步修改
- **提交前运行测试**：
  ```bash
  cd backend  && mvn test        # 后端 JUnit
  cd desktop  && pnpm test       # 桌面端 vitest
  cd mobile   && flutter test    # 移动端 dart test
  ```
- **不提交敏感信息**：`.env`、密钥、证书、用户数据、构建产物均已在 `.gitignore` 中忽略，请勿 `git add -f`

## 提交红线

- ❌ 不得提交 `.env`、密钥、证书、用户数据、构建产物
- ✅ 一个提交只做一件事，subject 用中文或英文简明描述
- ✅ 提交前跑相关端的测试

## 安全漏洞

请勿通过公开 Issue 报告安全漏洞。请按 [SECURITY.md](./SECURITY.md) 流程私密报告。
