# Changelog

> LifeScale 版本变更记录。遵循 [Keep a Changelog](https://keepachangelog.com/) 风格 + [Semantic Versioning](https://semver.org/)。

格式约定：

```text
## [版本号] - 日期
### Added      新增功能
### Changed    变更
### Deprecated 废弃
### Removed    移除
### Fixed      修复
### Security   安全
```

---

## [1.0.0] - 2026-06-29

> **开源本地版基线**：移除全部后端 / 云同步 / 网络层，改为纯本地应用。

### Changed
- **架构降为纯本地**：从「本地优先 + 多端云同步」改为「单机本地优先」。删除全部后端 / 云同步 / 多设备同步模型。
- **存储简化为两层**：本地 SQLite（当天热数据）+ 本地 Markdown Vault（沉淀归档）。移除云端 PostgreSQL、Redis、CAS 对象存储、Vault 文件同步通道。

### Removed
- 移除后端层（Spring Boot、Java、JPA、Flyway、Maven、`backend/`）。
- 移除云端 13 张表（ls_user / ls_user_profile / ls_device / ls_vault_file / ls_vault_version / ls_vault_conflict / ls_attachment / ls_invite_code / ls_feedback 等）及 sync.db 同步游标库。
- 移除云同步相关概念：鉴权登录、last-write-wins 同步、三方合并、冲突副本、墓碑传播。
- 移除部署编排（Docker Compose）、部署指南文档（`docs/deployment/部署指南.md`）。
- 移除移动端后端联调参数：打包脚本 `build-android` 的 `-ConnectBackend` / `-ApiBaseUrl`（对应 dart-defines `LIFESCALE_API_BASE_URL` / `LIFESCALE_USE_MOCK_API` 已随 app_config.dart 一并删除）。
- 移除 GitFlow 三环境模型（main=prod / staging=test / develop=dev）：纯本地应用无服务端可部署，简化为单 `main` 发布分支。

### Added
- 重写技术文档（架构 / 数据库 / 仓库结构 / 打包指南 / 文档索引）为纯本地视角。

> 历史变更记录见下方 [Unreleased] 段落（保留以备追溯；其中描述的三端 / 云端 / 后端内容已在 1.0.0 移除）。

---

## [Unreleased]

> 当前开发中、尚未发布的内容。
> 注：以下条目记录的是移除后端前的早期仓库初始化工作，其中涉及的「三端 / 云端 13 表 / backend / Flyway / Docker」等内容已在本版（1.0.0）全部移除。

### Added
- 初始化开源仓库结构：单代码仓（`lifescale/`）+ workspace 私有资产隔离。
- 新增 [`docs/database/schema.sql`](./docs/database/schema.sql) 作为两端表结构的**单一真相源**（本地 6 表）。
- 新增两端 CI（`.github/workflows/ci.yml`：pnpm `vitest` + Flutter `flutter test`）。
- 新增 GitHub 开源基础设施：Issue/PR 模板、dependabot 依赖监控。
- 重写开源技术文档（纯本地版）：架构 / 数据库 / 客户端打包指南。

### Changed
- **开源机制简化**：从「私有仓 → 脱敏脚本 → 两公开仓」改为「单仓两公开 remote 直推」。
- **配置层重写**：`.gitignore` 精简；真实签名材料迁出仓库至 `workspace/secrets/`。

### Removed
- 删除脱敏导出脚本（`scripts/sync-to-opensource.*`）—— 单仓直推后不再需要。
- 删除临时部署方案（`docker-compose.temp.yml`、`DEPLOY-TEMP.md`）。
- 删除冗余资源：移动端重复图片 `pic/`、空占位目录、开发期集成记录文档。

---

## 待发布里程碑

- `v0.1.0` —— MVP 首个正式版本（当前测试收尾中，发布后填入）。
