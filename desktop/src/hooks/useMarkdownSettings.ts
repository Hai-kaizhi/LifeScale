import { useCallback, useEffect, useMemo, useState } from 'react';
import { message } from 'antd';
import type { RequestStatus } from '../shared/types/api';
import type {
  DailyMarkdownListData,
  DailyMarkdownPermissions,
  MarkdownSettings,
  UpdateMarkdownSettingsPayload,
} from '../shared/types/dailyMarkdown';
import { useVaultSync } from './useVaultSync';
import { DEFAULT_DAILY_SUBDIRECTORY, dailyPathPattern } from '../shared/utils/markdownPaths';

export const MARKDOWN_SETTINGS_CHANGED_EVENT = 'lifescale:markdown-settings-changed';

const SETTINGS_STORAGE_KEY = 'lifescale.markdown.settings';

interface LocalMarkdownSettings {
  dailySubdirectory: string;
}

function loadLocalSettings(): LocalMarkdownSettings {
  const fallback: LocalMarkdownSettings = {
    dailySubdirectory: DEFAULT_DAILY_SUBDIRECTORY,
  };
  try {
    const raw = localStorage.getItem(SETTINGS_STORAGE_KEY);
    if (!raw) return fallback;
    const parsed = JSON.parse(raw) as Partial<LocalMarkdownSettings>;
    return {
      dailySubdirectory: parsed.dailySubdirectory?.trim() || DEFAULT_DAILY_SUBDIRECTORY,
    };
  } catch {
    return fallback;
  }
}

function persistLocalSettings(settings: LocalMarkdownSettings): void {
  try {
    localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(settings));
  } catch {
    /* ignore */
  }
}

function emitSettingsChanged(): void {
  window.dispatchEvent(new Event(MARKDOWN_SETTINGS_CHANGED_EVENT));
}

function buildPermissions(hasRoot: boolean): DailyMarkdownPermissions {
  return {
    canView: true,
    canEdit: hasRoot,
    canSave: hasRoot,
    canChooseFolder: true,
    canWriteToDisk: hasRoot,
    reason: hasRoot ? undefined : '请先在设置中选择工作区文件夹',
  };
}

const EMPTY_RECENT: DailyMarkdownListData = {
  list: [],
  total: 0,
  pageNo: 1,
  pageSize: 8,
  status: 'empty',
  permissions: {
    canView: true,
    canEdit: false,
    canSave: false,
    canChooseFolder: true,
    canWriteToDisk: false,
  },
};

interface UseMarkdownSettingsResult {
  settings: MarkdownSettings | null;
  recentDocuments: DailyMarkdownListData | null;
  status: RequestStatus;
  saving: boolean;
  choosing: boolean;
  error: string | null;
  hasSaveRoot: boolean;
  refetch: () => Promise<void>;
  chooseRootFolder: () => Promise<MarkdownSettings | null>;
  updateSettings: (payload: UpdateMarkdownSettingsPayload) => Promise<MarkdownSettings | null>;
}

/**
 * Markdown 设置（本地优先）：dailySubdirectory 以 localStorage 为源；
 * saveRootPath 统一为 vault 根（lifescale.vault.root）。已登录态 best-effort 镜像到云端。
 * serverMdRoot 属后端配置，前端 UI 不暴露，固定为空。
 */
export function useMarkdownSettings(): UseMarkdownSettingsResult {
  const { vaultRoot, chooseVaultFolder } = useVaultSync();
  const [local, setLocal] = useState<LocalMarkdownSettings>(() => loadLocalSettings());
  const [status, setStatus] = useState<RequestStatus>('success');
  const [saving, setSaving] = useState(false);
  const [choosing, setChoosing] = useState(false);
  const [error] = useState<string | null>(null);

  const hasSaveRoot = Boolean(vaultRoot);

  // 稳定 settings 引用：仅在实际值变化时变更，避免下游 effect 因新对象反复触发
  const settings = useMemo<MarkdownSettings>(
    () => ({
      saveRootPath: vaultRoot ?? '',
      dailySubdirectory: local.dailySubdirectory,
      dailyPathPattern: dailyPathPattern(local.dailySubdirectory),
      serverMdRoot: '',
      recentDocuments: [],
      permissions: buildPermissions(hasSaveRoot),
    }),
    [vaultRoot, local.dailySubdirectory, hasSaveRoot],
  );

  // 其它 useMarkdownSettings 实例 / vaultRoot 变化时同步
  useEffect(() => {
    const handler = () => setLocal(loadLocalSettings());
    window.addEventListener(MARKDOWN_SETTINGS_CHANGED_EVENT, handler);
    return () => window.removeEventListener(MARKDOWN_SETTINGS_CHANGED_EVENT, handler);
  }, []);

  // vaultRoot 变化（选/换工作区文件夹）→ 通知 useDailyDoc/useDailyMarkdown 重算路径
  useEffect(() => {
    emitSettingsChanged();
  }, [vaultRoot]);

  const refetch = useCallback(async () => {
    setLocal(loadLocalSettings());
    setStatus('success');
  }, []);

  const updateSettings = useCallback(
    async (payload: UpdateMarkdownSettingsPayload) => {
      setSaving(true);
      try {
        const next: LocalMarkdownSettings = {
          dailySubdirectory:
            payload.dailySubdirectory !== undefined
              ? payload.dailySubdirectory.trim() || DEFAULT_DAILY_SUBDIRECTORY
              : local.dailySubdirectory,
        };
        persistLocalSettings(next);
        setLocal(next);

        const updated: MarkdownSettings = {
          ...settings,
          dailySubdirectory: next.dailySubdirectory,
          dailyPathPattern: dailyPathPattern(next.dailySubdirectory),
        };
        message.success('保存位置已更新');
        emitSettingsChanged();
        return updated;
      } finally {
        setSaving(false);
      }
    },
    [local.dailySubdirectory, vaultRoot, settings],
  );

  const chooseRootFolder = useCallback(async () => {
    setChoosing(true);
    try {
      await chooseVaultFolder();
      emitSettingsChanged();
      return settings;
    } catch {
      message.error('选择文件夹失败');
      return null;
    } finally {
      setChoosing(false);
    }
  }, [chooseVaultFolder, settings]);

  return {
    settings,
    recentDocuments: EMPTY_RECENT,
    status,
    saving,
    choosing,
    error,
    hasSaveRoot,
    refetch,
    chooseRootFolder,
    updateSettings,
  };
}
