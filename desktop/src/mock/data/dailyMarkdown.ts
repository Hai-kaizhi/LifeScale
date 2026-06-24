import dayjs from 'dayjs';
import type {
  DailyMarkdownDocument,
  DailyMarkdownStatus,
  MarkdownSettings,
  UpdateMarkdownSettingsPayload,
} from '../../shared/types/dailyMarkdown';
import { getWeekday } from '../../shared/utils/date';
import { joinPath, normalizeRootPath, dailyRelativePath } from '../../shared/utils/markdownPaths';

/**
 * Markdown 设置 mock 数据（仅 settings 相关）。
 *
 * 历史 generate/source/list/saved 等 mock 数据构建随 Model B 后端接口废弃删除
 *（它们依赖已删除的 mock/data/dailyReview、dateEntity）。
 * Daily 文档正文改由本地 vault Markdown 文件承载（services/vault/*）。
 */
const SETTINGS_STORAGE_KEY = 'lifescale.mock.markdown-settings.v1';
const DAILY_SUBDIRECTORY = 'Daily';
const DAILY_PATH_PATTERN = 'Daily/YYYY-MM-DD.md';

let settingsStore: MarkdownSettings = loadSettings();

function basePermissions() {
  const hasRoot = Boolean(settingsStore.saveRootPath);
  return {
    canView: true,
    canEdit: hasRoot,
    canSave: hasRoot,
    canChooseFolder: true,
    canWriteToDisk: hasRoot,
    reason: hasRoot ? undefined : '请先在设置中选择 Markdown 保存位置',
  };
}

function loadSettings(): MarkdownSettings {
  const fallback: MarkdownSettings = {
    saveRootPath: '',
    dailySubdirectory: DAILY_SUBDIRECTORY,
    dailyPathPattern: DAILY_PATH_PATTERN,
    recentDocuments: [],
    permissions: {
      canView: true,
      canEdit: false,
      canSave: false,
      canChooseFolder: true,
      canWriteToDisk: false,
      reason: '请先在设置中选择 Markdown 保存位置',
    },
  };

  if (typeof window === 'undefined') {
    return fallback;
  }

  try {
    const raw = window.localStorage.getItem(SETTINGS_STORAGE_KEY);
    if (!raw) return fallback;
    const parsed = JSON.parse(raw) as Partial<MarkdownSettings>;
    return {
      ...fallback,
      saveRootPath: parsed.saveRootPath ?? '',
      recentDocuments: parsed.recentDocuments ?? [],
    };
  } catch {
    return fallback;
  }
}

function persistSettings(): void {
  settingsStore = {
    ...settingsStore,
    permissions: basePermissions(),
  };

  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(settingsStore));
  } catch {
    // Mock persistence is best-effort only.
  }
}

export function getMarkdownSettings(): MarkdownSettings {
  settingsStore = {
    ...settingsStore,
    permissions: basePermissions(),
  };
  return {
    ...settingsStore,
    recentDocuments: settingsStore.recentDocuments.map((item) => ({ ...item })),
  };
}

export function updateMarkdownSettings(payload: UpdateMarkdownSettingsPayload): MarkdownSettings {
  settingsStore = {
    ...settingsStore,
    saveRootPath:
      payload.saveRootPath !== undefined ? normalizeRootPath(payload.saveRootPath) : settingsStore.saveRootPath,
    dailySubdirectory:
      payload.dailySubdirectory !== undefined
        ? payload.dailySubdirectory.trim() || DAILY_SUBDIRECTORY
        : settingsStore.dailySubdirectory,
  };
  persistSettings();

  return getMarkdownSettings();
}

/* ============================ 知识库 mock 兼容 ============================ */
// 下列函数仅供 mock/data/knowledgeBase.ts 的 Daily 文档展示与搜索使用。
// 历史 generate/source 逻辑依赖已删除的 dailyReview/dateEntity mock，这里提供简化存根：
// Daily 文档正文实际由本地 vault Markdown 文件承载，mock 场景返回占位内容即可。

const dailyDocuments = new Map<string, DailyMarkdownDocument>();

function getTitle(date: string): string {
  return `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`;
}

function createEmptyDailyDocument(date: string, status: DailyMarkdownStatus): DailyMarkdownDocument {
  const relativePath = dailyRelativePath(date, DAILY_SUBDIRECTORY);
  return {
    date,
    title: getTitle(date),
    fileName: `${date}.md`,
    relativePath,
    absolutePath: joinPath(settingsStore.saveRootPath, relativePath),
    content: '',
    updatedAt: new Date().toISOString(),
    status,
    permissions: basePermissions(),
  };
}

export function getDailyMarkdownDocument(date: string): DailyMarkdownDocument {
  const existing = dailyDocuments.get(date);
  if (existing) {
    return {
      ...existing,
      absolutePath: joinPath(settingsStore.saveRootPath, existing.relativePath),
      permissions: basePermissions(),
      status: settingsStore.saveRootPath ? existing.status : 'missing_save_root',
    };
  }
  return createEmptyDailyDocument(date, settingsStore.saveRootPath ? 'empty' : 'missing_save_root');
}

export function generateDailyMarkdownDocument(date: string): DailyMarkdownDocument {
  const relativePath = dailyRelativePath(date, DAILY_SUBDIRECTORY);
  const now = new Date().toISOString();
  const document: DailyMarkdownDocument = {
    date,
    title: getTitle(date),
    fileName: `${date}.md`,
    relativePath,
    absolutePath: joinPath(settingsStore.saveRootPath, relativePath),
    content: `# ${getTitle(date)}\n\n（mock 占位内容，真实内容由本地 vault Markdown 文件承载）\n`,
    updatedAt: now,
    status: settingsStore.saveRootPath ? 'ok' : 'missing_save_root',
    permissions: basePermissions(),
  };
  dailyDocuments.set(date, document);
  return { ...document };
}

export function markDailyMarkdownSaved(date: string): DailyMarkdownDocument {
  const previous = getDailyMarkdownDocument(date);
  const savedAt = new Date().toISOString();
  const document: DailyMarkdownDocument = {
    ...previous,
    savedAt,
    updatedAt: savedAt,
    status: settingsStore.saveRootPath ? 'ok' : 'missing_save_root',
    permissions: basePermissions(),
  };
  dailyDocuments.set(date, document);
  return { ...document };
}
