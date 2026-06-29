# LifeScale 文档

本目录是 LifeScale 的**开源本地版技术文档**。纯本地应用，不含任何后端 / 云同步 / 服务端内容。

## 目录索引

### 架构（architecture/）
- [技术架构](./architecture/技术架构.md) —— 本地优先 + SQL-first 真相源 + 两层存储（SQLite + Markdown Vault）+ 沉淀模型
- [开源仓库架构](./architecture/开源仓库架构.md) —— 单仓两公开 remote 模型 + 分支策略 + 发版流程

### 数据库（database/）
- [Schema 单一真相源](./database/schema.sql) —— 本地 SQLite 6 表（**两端表结构以此为准**）
- [Daily 数据架构](./database/Daily数据架构.md) —— 沉淀分层模型（热/温/冷）与本地持久化

### 打包（deployment/）
- [客户端打包指南](./deployment/客户端打包指南.md) —— 桌面端 / 移动端打包 + 签名 + 版本号

## 相关

- 项目总览：[`README.md`](../README.md)（仓库根）
- 变更记录：[`CHANGELOG.md`](../CHANGELOG.md)
- 贡献指南：[`CONTRIBUTING.md`](../CONTRIBUTING.md)
