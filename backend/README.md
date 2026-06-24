# LifeScale 后端

本目录是 LifeScale 第 0 步后端 API 工程底座。

## 技术栈

- Java 21
- Maven
- Spring Boot 3.5.x
- PostgreSQL
- Redis
- OpenAPI / Swagger UI

## 常用命令

运行测试：

```powershell
mvn test
```

启动 API：

```powershell
mvn spring-boot:run
```

打包应用：

```powershell
mvn clean package
```

## 接口

健康检查：

```text
GET http://localhost:8080/api/health
```

接口文档：

```text
http://localhost:8080/swagger-ui.html
http://localhost:8080/v3/api-docs
```

## 配置

默认本地配置来自 `src/main/resources/application.yml`，也可以通过环境变量覆盖：

- `SERVER_PORT`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `REDIS_HOST`
- `REDIS_PORT`

本地 Docker 中 PostgreSQL 默认映射到 `localhost:15432`，Redis 默认映射到 `localhost:16379`。容器内部仍使用 PostgreSQL `5432` 和 Redis `6379`。

## 模块边界

以下包仅作为后续阶段的模块边界预留：

- `user`：用户与账号能力
- `today`：今日能力和日期归属
- `task`：今日任务
- `timeblock`：时间块
- `record`：快速记录
- `review`：今日复盘
- `document`：Markdown 文档元信息
- `sync`：多端同步

第 0 步只开放 `/api/health`。在进入对应产品阶段前，不得新增业务 API。
