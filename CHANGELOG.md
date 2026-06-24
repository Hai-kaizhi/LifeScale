# Changelog

> LifeScale 版本变更记录。遵循 [Keep a Changelog](https://keepachangelog.com/) 风格 + [Semantic Versioning](https://semver.org/)。
> 版本号规范见《项目规范化与迭代开发指南.md》§4。

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

## [Unreleased]

> 当前开发中、尚未发布的内容。

### Added
- **工程化整改**：新增 `docs/STATUS_当前真实状态总览.md`（权威现状入口，修复悬空引用）。
- **工程化整改**：新增《项目规范化与迭代开发指南.md》（git 流程 / 需求模板 / 提交规范 / .env 规范）。
- **工程化整改**：新增 `docs/10_项目整改方案与执行计划.md`（整改方案与执行记录）。
- **工程化整改**：新增 `code/docker/docker-compose.staging.yml` + `.env.staging.example`（staging 环境隔离）。
- **工程化整改**：新增 `code/desktop/.env.example`（前端 .env 模板）。
- **工程化整改**：新增 `docs/templates/需求模板.md`（标准化需求模板）。

### Changed
- **工程化整改**：重写 `docs/08_开发与部署工作流.md` v2.0（补全 MVP 迭代衔接 + staging 落地 + 完整需求闭环 + 修复悬空引用）。
- **工程化整改**：强化 `code/start.bat`（启动前自检残留容器 + 8080 端口占用检查）。
- **工程化整改**：强化 `code/stop.bat`（全栈编排清理 + 兜底删残留 backend 容器）。
- **工程化整改**：`.env.example` / `.env.production.example` 加显式用途注释头，消除 "--env-file 陷阱"。
- **工程化整改**：更新 `README.md` / `CLAUDE.md`，修复悬空链接，反映整改后的文档体系。

### Fixed
- **工程化整改**：修复 Docker 残留 `lifescale-backend` 容器抢占 8080 端口导致 `start.bat` 失败的问题。

---

## [历史提交] - 2026-06-22 之前

> 以下为整改前已合并到 main 的关键提交，非正式版本号（MVP 尚未发布首个正式版本）。

### Added
- `refactor(arch)`: Daily 沉淀分层与 SQL 真相源重构（docs/09 P0-P6）。
- `feat(auth)`: 支持离线优先免登录模式（鉴权三态 local/authenticated）。
- `feat(deploy)`: 临时上线方案（域名审核期间 IP:8080，`docker-compose.temp.yml`）。

### Changed
- `perf(build)`: Maven 依赖阿里云镜像加速（构建 9 分钟→2-3 分钟）。
- `fix(deploy)`: 修正部署文档路径 - 去掉多余的 code/ 中间层。

---

## 待发布里程碑

- `v0.1.0` —— MVP 首个正式版本（当前测试收尾中，发布后填入）。
