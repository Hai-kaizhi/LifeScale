# LifeScale

> 本地优先（Local-First）的 Markdown Vault 多端同步应用。本地数据库为真相源，支持桌面端、移动端、云端三端，离线可用，登录后自动云同步。

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

## 功能特性

- **本地优先**：所有数据默认存在本地 SQLite，离线完整可用
- **多端同步**：桌面端（Tauri + React）/ 移动端（Flutter）/ 云端三端，登录后自动云同步
- **Markdown Vault**：以 Markdown 文件为存储载体，沉淀分层（热/温/冷）
- **冲突安全**：乐观锁 + 三方合并 + 冲突副本 + 墓碑，永不丢数据
- **附件存储**：CAS 内容寻址存储，支持磁盘 / S3 / 腾讯云 COS

## 技术栈

| 模块 | 技术 | 包管理 |
| --- | --- | --- |
| 后端 | Spring Boot 3.5 + Java 21 + JPA + Flyway | Maven |
| 桌面端 | Tauri 2 + React 19 + TypeScript + Vite | pnpm |
| 移动端 | Flutter + Riverpod + go_router + Dio | pub |
| 数据库 | PostgreSQL 16 | - |
| 缓存 | Redis 7 | - |
| 编排 | Docker Compose | - |

## 目录结构

```text
backend/    Spring Boot 3.5 + Java 21 后端 API
desktop/    Tauri 2 + React 19 桌面端
mobile/     Flutter 移动端
docker/     Docker Compose 编排（PG + Redis + backend）
scripts/    工具脚本
start.bat   一键启动完整开发链路（Windows）
stop.bat    一键停止并释放端口（Windows）
```

## 快速开始

### 前置要求

- Docker Desktop 已启动
- JDK 21、Node 20+、pnpm 10、Flutter SDK 已安装

### 一键启动（本地开发）

```powershell
.\start.bat      # docker 依赖(PG+Redis) → 后端 mvn 热重载 → Tauri 桌面端
.\stop.bat       # 停止全部并释放端口
```

### 分端启动

```bash
# 后端
cd backend && mvn spring-boot:run

# 桌面端
cd desktop && pnpm install && pnpm tauri dev
# 或 pnpm dev          # 仅 web 预览（无 Tauri FS bridge，文件写模拟）

# 移动端
cd mobile && flutter pub get && flutter run                                  # 默认 mock API
flutter run --dart-define=LIFESCALE_USE_MOCK_API=false                      # 真实后端
```

### Docker 全栈（本地验证 prod profile）

```bash
cd docker
cp .env.production.example .env    # 复制模板并填入真实值（替换所有 ChangeMe）
docker compose -f docker-compose.full.yml up -d --build
```

### 端口约定

| 服务 | 宿主机端口 | 说明 |
| --- | --- | --- |
| 桌面端 Vite | 5173 | Tauri 开发模式 |
| 后端 API | 8080 | Spring Boot |
| PostgreSQL | 15432 | 容器内 5432（避开本机 5432） |
| Redis | 16379 | 容器内 6379（避开本机 6379） |

PG/Redis 用非标准宿主端口是有意为之，避免误占本机或 WSL 常见的 5432/6379。

### 验证

- 健康检查：`GET http://localhost:8080/api/health` → `{"status":"UP"}`
- Swagger UI：`http://localhost:8080/swagger-ui.html`
- OpenAPI JSON：`http://localhost:8080/v3/api-docs`
- 桌面端 web 预览：`http://localhost:5173`

## 部署

生产部署使用 Docker Compose 全栈编排：

```bash
cd docker
cp .env.production.example .env    # 复制模板并填入真实值
# 编辑 .env，替换所有 ChangeMe 为强随机值
docker compose -f docker-compose.full.yml up -d --build
```

详细部署配置见 `docker/README.md`。

⚠️ 生产环境必须修改 `.env` 中所有 `ChangeMe` 占位符为强随机值（后端会对弱 JWT secret / 弱 bootstrap 密码 fail-fast 拒绝启动）。

强随机值生成：
```bash
openssl rand -base64 48    # JWT secret（≥32 字节）
openssl rand -base64 24    # PostgreSQL / Redis 密码
```

## 测试

```bash
cd backend  && mvn test        # 后端 JUnit
cd desktop  && pnpm test       # 桌面端 vitest
cd mobile   && flutter test    # 移动端 dart test
```

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
