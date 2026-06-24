# LifeScale Docker

本目录用于编排 LifeScale 第 0 步本地开发依赖。

## 服务

- PostgreSQL：`localhost:15432`
- Redis：`localhost:16379`

容器内部仍使用标准端口：PostgreSQL `5432`，Redis `6379`。

## 常用命令

启动依赖：

```powershell
docker compose up -d
```

查看状态：

```powershell
docker compose ps
```

停止依赖：

```powershell
docker compose down
```

## 默认配置

Compose 文件提供安全的本地默认值：

- `POSTGRES_DB=lifescale`
- `POSTGRES_USER=lifescale`
- `POSTGRES_PASSWORD=lifescale_local_password`
- `POSTGRES_PORT=15432`
- `REDIS_PORT=16379`

如需本机覆盖配置，可以在本目录创建不提交版本库的 `.env` 文件。

Docker 只用于本地开发、测试、私有化部署和自托管环境。普通桌面端用户不应被要求安装 PostgreSQL、Redis 或 Docker。
