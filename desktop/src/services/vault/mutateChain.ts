/**
 * 按 vaultPath 串行化「读-改-写」任务。同一 vault 文件可能被多个 hook 实例编辑
 * （如同一每日文档被 TodayPage 日程段 + QuickNotes 快速记录段编辑；scheme 文件被多处引用），
 * 全局链确保每次写入都基于磁盘最新内容，避免后写者用陈旧模型覆盖另一段的改动。
 */
const chains = new Map<string, Promise<void>>();

/** 将 task 串到 key 的链尾执行，返回该次任务结束的 promise。 */
export function runChained(key: string, task: () => Promise<void>): Promise<void> {
  const prev = chains.get(key) ?? Promise.resolve();
  const next = prev.catch(() => undefined).then(task).catch(() => undefined);
  chains.set(key, next);
  return next;
}
