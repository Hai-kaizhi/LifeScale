import { API_BASE_URL } from "../services/apiConfig";

const foundationItems = [
  {
    title: "桌面端",
    detail: "Tauri 2 + React + TypeScript + Vite 桌面端外壳已就绪。",
  },
  {
    title: "后端服务",
    detail: "Spring Boot API 已按配置地址预留。",
  },
  {
    title: "阶段边界",
    detail: "当前仅为第 0 步，产品功能从后续阶段开始。",
  },
] as const;

export function FoundationReadyPage() {
  return (
    <main className="foundation-page">
      <section className="foundation-panel" aria-labelledby="foundation-title">
        <p className="foundation-eyebrow">LifeScale 第 0 步</p>
        <h1 className="foundation-title" id="foundation-title">
          LifeScale 桌面端工程底座已就绪
        </h1>
        <p className="foundation-summary">
          当前版本只验证技术部署、项目结构、配置边界和启动链路，不包含今日、任务、复盘或 Markdown 业务功能。
        </p>

        <div className="foundation-grid" aria-label="工程底座状态">
          {foundationItems.map((item) => (
            <article className="foundation-item" key={item.title}>
              <strong>{item.title}</strong>
              <span>{item.detail}</span>
            </article>
          ))}
        </div>

        <p className="foundation-note">后端 API 地址：{API_BASE_URL}</p>
      </section>
    </main>
  );
}
