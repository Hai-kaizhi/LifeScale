import { useCallback, useMemo } from 'react';
import { message } from 'antd';
import type { RequestStatus } from '../shared/types/api';
import type {
  QuickNote,
  QuickNoteListStatus,
  QuickNotePermissions,
} from '../shared/types/quickNote';
import { useDailyDoc } from './vault/useDailyDoc';

function newId(): string {
  try {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID();
    }
  } catch {
    /* fallthrough */
  }
  return `qn-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/** 本地优先下的完全可读写权限。 */
const LOCAL_PERMISSIONS: QuickNotePermissions = {
  canView: true,
  canCreate: true,
  canUpdate: true,
  canDelete: true,
};

function sortNotes(notes: QuickNote[]): QuickNote[] {
  // createdAt 为完整 ISO；同分钟稳定排序保留文件序（新建项用完整 ISO 以置顶）
  return [...notes].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

interface UseQuickNotesResult {
  notes: QuickNote[];
  recentNotes: QuickNote[];
  total: number;
  status: RequestStatus;
  listStatus: QuickNoteListStatus;
  error: string | null;
  permissions: QuickNotePermissions;
  creating: boolean;
  updatingId: string | null;
  deletingId: string | null;
  detailLoadingId: string | null;
  refetch: () => Promise<void>;
  createNote: (content: string) => Promise<boolean>;
  loadNoteDetail: (id: string) => Promise<QuickNote | null>;
  updateNote: (id: string, content: string) => Promise<boolean>;
  deleteNote: (id: string) => Promise<boolean>;
}

/**
 * 快速记录（本地优先）：基于当日 Daily Doc 的「快速记录」段（经 useDailyDoc）。
 * 增删改即时更新内存模型 → 序列化整文 → 经 vault 引擎写本地 + 防抖推送。
 */
export function useQuickNotes(date: string): UseQuickNotesResult {
  const { model, loading, setQuickNotes } = useDailyDoc(date);

  const notes = useMemo(() => (model ? sortNotes(model.quickNotes) : []), [model]);
  const recentNotes = useMemo(() => notes.slice(0, 4), [notes]);
  const total = notes.length;
  const status: RequestStatus = loading ? 'loading' : 'success';
  const listStatus: QuickNoteListStatus = notes.length ? 'ok' : 'empty';

  const createNote = useCallback(
    async (content: string): Promise<boolean> => {
      const trimmed = content.trim();
      if (!trimmed) return false;
      const now = new Date().toISOString();
      const note: QuickNote = {
        id: newId(),
        date,
        content: trimmed,
        sourceDevice: 'desktop',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      };
      setQuickNotes((prev) => [...prev, note]);
      message.success('记录已保存');
      return true;
    },
    [date, setQuickNotes],
  );

  const updateNote = useCallback(
    async (id: string, content: string): Promise<boolean> => {
      const trimmed = content.trim();
      if (!trimmed) return false;
      const now = new Date().toISOString();
      setQuickNotes((prev) =>
        prev.map((item) => (item.id === id ? { ...item, content: trimmed, updatedAt: now } : item)),
      );
      message.success('记录已更新');
      return true;
    },
    [setQuickNotes],
  );

  const deleteNote = useCallback(
    async (id: string): Promise<boolean> => {
      setQuickNotes((prev) => prev.filter((item) => item.id !== id));
      message.success('记录已删除');
      return true;
    },
    [setQuickNotes],
  );

  const loadNoteDetail = useCallback(
    async (id: string): Promise<QuickNote | null> => {
      return notes.find((item) => item.id === id) ?? null;
    },
    [notes],
  );

  const refetch = useCallback(async () => {
    /* 本地优先：数据由 useDailyDoc 响应式驱动，无需主动拉取 */
  }, []);

  return {
    notes,
    recentNotes,
    total,
    status,
    listStatus,
    error: null,
    permissions: LOCAL_PERMISSIONS,
    creating: false,
    updatingId: null,
    deletingId: null,
    detailLoadingId: null,
    refetch,
    createNote,
    loadNoteDetail,
    updateNote,
    deleteNote,
  };
}
