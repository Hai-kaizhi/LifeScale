/**
 * 前端 Markdown 路径工具（本地优先）：统一每日文档路径拼装，去重 mock/页面/service 三处复制。
 *
 * 约定：vault 根目录为本地事实来源；每日文档 = `<dailySubdir>/<date>.md`（相对 vault 根）。
 */

export const DEFAULT_DAILY_SUBDIRECTORY = 'Daily';

/** 规整根目录：去首尾空白与尾部路径分隔符。 */
export function normalizeRootPath(path: string): string {
  return path.trim().replace(/[\\/]+$/, '');
}

/** 每日文档相对路径（相对 vault 根）：<subdir>/<date>.md。 */
export function dailyRelativePath(date: string, subdir: string = DEFAULT_DAILY_SUBDIRECTORY): string {
  const cleanSub = subdir.trim() || DEFAULT_DAILY_SUBDIRECTORY;
  return `${cleanSub}/${date}.md`;
}

/** 每日文档路径模式（含占位）：<subdir>/YYYY-MM-DD.md。 */
export function dailyPathPattern(subdir: string = DEFAULT_DAILY_SUBDIRECTORY): string {
  const cleanSub = subdir.trim() || DEFAULT_DAILY_SUBDIRECTORY;
  return `${cleanSub}/YYYY-MM-DD.md`;
}

/**
 * 把相对路径接到根目录上，按根目录是否含反斜杠自动选择分隔符（Windows 用 `\`）。
 */
export function joinPath(rootPath: string, relativePath: string): string {
  const root = normalizeRootPath(rootPath);
  if (!root) return relativePath;
  const separator = root.includes('\\') ? '\\' : '/';
  return `${root}${separator}${relativePath.replace(/\//g, separator)}`;
}
