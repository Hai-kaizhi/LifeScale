# LifeScale 桌面端

本目录是 LifeScale 第 0 步桌面端工程底座。

## 技术栈

- Tauri 2
- React
- TypeScript
- Vite
- pnpm

## 常用命令

安装依赖：

```powershell
pnpm install
```

启动 Web 预览：

```powershell
pnpm dev
```

启动 Tauri 桌面端：

```powershell
pnpm tauri dev
```

构建前端资源：

```powershell
pnpm build
```

构建桌面端安装包：

```powershell
pnpm tauri build
```

## 本地配置

桌面端通过 `VITE_API_BASE_URL` 指向后端 API。

默认值：

```text
http://localhost:8080/api
```

## 目录边界

```text
src/
  app/          应用入口和全局样式
  pages/        页面级视图
  components/   可复用 UI 组件
  features/     后续产品功能模块
  services/     API 和平台能力边界
  shared/       共享常量、类型和工具函数
src-tauri/      Tauri Rust 外壳和桌面端配置
```

第 0 步不得实现今日入口、任务、时间块、快速记录、复盘、Markdown 沉淀、日历回看或同步行为。
