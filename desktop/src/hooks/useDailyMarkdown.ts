import { useCallback, useEffect, useMemo, useState } from 'react';
import { message } from 'antd';
import dayjs from 'dayjs';
import type { RequestStatus } from '../shared/types/api';
import type {
  DailyMarkdownDocument,
  DailyMarkdownPermissions,
  DailyMarkdownStatus,
} from '../shared/types/dailyMarkdown';
import { getVaultEngineSingleton } from '../services/vault';
import {
  DEFAULT_DAILY_SUBDIRECTORY,
  dailyRelativePath,
  joinPath,
} from '../shared/utils/markdownPaths';
import { getWeekday } from '../shared/utils/date';
import { useVaultSync } from './useVaultSync';
import { useMarkdownSettings } from './useMarkdownSettings';

interface UseDailyMarkdownResult {
  document: DailyMarkdownDocument | null;
  status: RequestStatus;
  error: string | null;
  generating: boolean;
  savingSource: boolean;
  refetch: () => Promise<void>;
  generateAndWrite: () => Promise<DailyMarkdownDocument | null>;
  saveSource: (content: string) => Promise<DailyMarkdownDocument | null>;
}

function getTitle(date: string): string {
  return `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`;
}

/** 空白日期最小种子模板（doc §3.5）。 */
function buildSeed(date: string): string {
  return [
    `# ${getTitle(date)}`,
    '',
    '## 今日重点',
    '暂无今日重点。',
    '',
    '## 今日日程',
    '暂无日程。',
    '',
    '## 快速记录',
    '暂无快速记录。',
    '',
    '## 今日复盘',
    '暂无复盘内容。',
    '',
  ].join('\n');
}

function buildPermissions(hasRoot: boolean): DailyMarkdownPermissions {
  return {
    canView: true,
    canEdit: hasRoot,
    canSave: hasRoot,
    canChooseFolder: true,
    canWriteToDisk: hasRoot,
    reason: hasRoot ? undefined : '请先选择工作区文件夹',
  };
}

/**
 * 每日文档（本地优先 · raw 层）：以本地 vault 文件 <subdir>/<date>.md 为源，
 * 经 vault 引擎读写（即时落本地 → 防抖推送）。供 ReviewPage「查看 Markdown」等使用。
 * 后端 generate/saveSource 不再调用；文件为源、只读不再从 DB 重新生成覆盖。
 */
export function useDailyMarkdown(date: string): UseDailyMarkdownResult {
  const engine = getVaultEngineSingleton();
  const { vaultRoot } = useVaultSync();
  const { settings } = useMarkdownSettings();
  const dailySubdir = settings?.dailySubdirectory ?? DEFAULT_DAILY_SUBDIRECTORY;

  const dailyPath = useMemo(() => dailyRelativePath(date, dailySubdir), [date, dailySubdir]);
  const hasRoot = Boolean(vaultRoot);

  const [content, setContent] = useState('');
  const [status, setStatus] = useState<RequestStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);
  const [savingSource, setSavingSource] = useState(false);

  const buildDoc = useCallback(
    (raw: string): DailyMarkdownDocument => ({
      date,
      title: getTitle(date),
      fileName: `${date}.md`,
      relativePath: dailyPath,
      absolutePath: vaultRoot ? joinPath(vaultRoot, dailyPath) : dailyPath,
      content: raw,
      updatedAt: new Date().toISOString(),
      status: (raw.trim() ? 'ok' : 'empty') as DailyMarkdownStatus,
      permissions: buildPermissions(hasRoot),
    }),
    [date, dailyPath, vaultRoot, hasRoot],
  );

  const readDoc = useCallback(async () => {
    if (!vaultRoot) {
      setContent('');
      setStatus('idle');
      setError(null);
      return;
    }
    setStatus('loading');
    setError(null);
    try {
      const raw = await engine.readLocalFile(dailyPath);
      setContent(raw);
      setStatus('success');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Markdown 文档加载失败');
      setStatus('error');
    }
  }, [engine, vaultRoot, dailyPath]);

  useEffect(() => {
    void readDoc();
  }, [readDoc]);

  const document = useMemo<DailyMarkdownDocument | null>(() => {
    if (!vaultRoot) return null;
    return buildDoc(content);
  }, [vaultRoot, buildDoc, content]);

  const generateAndWrite = useCallback(async (): Promise<DailyMarkdownDocument | null> => {
    if (!vaultRoot) {
      message.warning('请先选择工作区文件夹');
      return null;
    }
    setGenerating(true);
    try {
      let raw = await engine.readLocalFile(dailyPath);
      if (!raw.trim()) {
        // 无文件时写最小种子（不在浏览日期时预创建，仅此处按需）
        raw = buildSeed(date);
        await engine.onContentChange(dailyPath, raw);
      }
      setContent(raw);
      return buildDoc(raw);
    } catch {
      message.error('Markdown 文档生成失败');
      return null;
    } finally {
      setGenerating(false);
    }
  }, [engine, vaultRoot, dailyPath, date, buildDoc]);

  const saveSource = useCallback(
    async (next: string): Promise<DailyMarkdownDocument | null> => {
      if (!vaultRoot) {
        message.warning('请先选择工作区文件夹');
        return null;
      }
      setSavingSource(true);
      try {
        await engine.onContentChange(dailyPath, next);
        setContent(next);
        return buildDoc(next);
      } catch {
        message.error('Markdown 源码保存失败');
        return null;
      } finally {
        setSavingSource(false);
      }
    },
    [engine, vaultRoot, dailyPath, buildDoc],
  );

  return {
    document,
    status,
    error,
    generating,
    savingSource,
    refetch: readDoc,
    generateAndWrite,
    saveSource,
  };
}
