import { useCallback, useEffect, useMemo, useState } from 'react';
import { message } from 'antd';
import { getVaultEngineSingleton } from '../../services/vault';
import { runChained } from '../../services/vault/mutateChain';
import {
  OFFICIAL_SCHEME_ID,
  SCHEME_VAULT_PATH,
  applySchemeUpdate,
  buildSchemeFromPayload,
  parseSchemeDoc,
  serializeSchemeDoc,
  type ReviewSchemeStore,
} from '../../services/vault/reviewScheme';
import type {
  CreateReviewQuestionSchemePayload,
  ReviewQuestionScheme,
  UpdateReviewQuestionSchemePayload,
} from '../../shared/types/dailyReview';
import { useVaultSync } from '../useVaultSync';

interface UseReviewSchemeResult {
  schemes: ReviewQuestionScheme[];
  activeScheme: ReviewQuestionScheme;
  loading: boolean;
  saving: boolean;
  deletingId: string | null;
  createScheme: (payload: CreateReviewQuestionSchemePayload) => Promise<ReviewQuestionScheme | null>;
  updateScheme: (payload: UpdateReviewQuestionSchemePayload) => Promise<ReviewQuestionScheme | null>;
  deleteScheme: (id: string) => Promise<boolean>;
  selectScheme: (id: string) => Promise<void>;
}

/**
 * 复盘方案（本地优先）：方案存为 vault 文件 `Reviews/scheme.md`（JSON-in-Markdown），
 * 经 vault 引擎读写 + 同步。增删改/切换方案 → 读-改-写整文件（按 SCHEME_VAULT_PATH 串行）。
 */
export function useReviewScheme(): UseReviewSchemeResult {
  const engine = getVaultEngineSingleton();
  const { vaultRoot } = useVaultSync();
  // 初始用默认方案（parseSchemeDoc('') 返回默认深拷贝）；挂载后从 Reviews/scheme.md 覆盖
  const [store, setStore] = useState<ReviewSchemeStore>(() => parseSchemeDoc(''));
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const readScheme = useCallback(async () => {
    if (!vaultRoot) return;
    setLoading(true);
    try {
      const raw = await engine.readLocalFile(SCHEME_VAULT_PATH);
      setStore(parseSchemeDoc(raw));
    } finally {
      setLoading(false);
    }
  }, [engine, vaultRoot]);

  useEffect(() => {
    void readScheme();
  }, [readScheme]);

  useEffect(() => {
    const off = engine.onFileChanged((paths) => {
      if (paths.includes(SCHEME_VAULT_PATH)) void readScheme();
    });
    return off;
  }, [engine, readScheme]);

  /** 基于磁盘最新内容的「读-改-写」（按 scheme 文件路径串行）。 */
  const mutateScheme = useCallback(
    (apply: (cur: ReviewSchemeStore) => ReviewSchemeStore): Promise<void> => {
      if (!vaultRoot) return Promise.resolve();
      return runChained(SCHEME_VAULT_PATH, async () => {
        const raw = await engine.readLocalFile(SCHEME_VAULT_PATH);
        const cur = parseSchemeDoc(raw);
        const next = apply(cur);
        setStore(next);
        await engine.onContentChange(SCHEME_VAULT_PATH, serializeSchemeDoc(next));
      });
    },
    [engine, vaultRoot],
  );

  const createScheme = useCallback(
    async (payload: CreateReviewQuestionSchemePayload): Promise<ReviewQuestionScheme | null> => {
      const scheme = buildSchemeFromPayload(payload);
      if (!scheme) {
        message.error('复盘方案创建失败');
        return null;
      }
      setSaving(true);
      try {
        await mutateScheme((cur) => ({ ...cur, schemes: [...cur.schemes, scheme] }));
        message.success('复盘方案已创建');
        return scheme;
      } finally {
        setSaving(false);
      }
    },
    [mutateScheme],
  );

  const updateScheme = useCallback(
    async (payload: UpdateReviewQuestionSchemePayload): Promise<ReviewQuestionScheme | null> => {
      setSaving(true);
      try {
        let updated: ReviewQuestionScheme | null = null;
        await mutateScheme((cur) => {
          const current = cur.schemes.find((item) => item.id === payload.id);
          if (!current) return cur;
          updated = applySchemeUpdate(current, payload);
          if (!updated) return cur;
          return { ...cur, schemes: cur.schemes.map((item) => (item.id === payload.id ? updated! : item)) };
        });
        if (!updated) {
          message.error('复盘方案更新失败');
          return null;
        }
        message.success('复盘方案已更新');
        return updated;
      } finally {
        setSaving(false);
      }
    },
    [mutateScheme],
  );

  const deleteScheme = useCallback(
    async (id: string): Promise<boolean> => {
      setDeletingId(id);
      try {
        await mutateScheme((cur) => {
          const target = cur.schemes.find((item) => item.id === id);
          if (!target || target.source === 'official') return cur;
          const schemes = cur.schemes.filter((item) => item.id !== id);
          const activeSchemeId =
            cur.activeSchemeId === id ? schemes[0]?.id ?? OFFICIAL_SCHEME_ID : cur.activeSchemeId;
          return { activeSchemeId, schemes };
        });
        message.success('复盘方案已删除');
        return true;
      } finally {
        setDeletingId(null);
      }
    },
    [mutateScheme],
  );

  const selectScheme = useCallback(
    (id: string): Promise<void> => mutateScheme((cur) => ({ ...cur, activeSchemeId: id })),
    [mutateScheme],
  );

  const activeScheme = useMemo(
    () => store.schemes.find((item) => item.id === store.activeSchemeId) ?? store.schemes[0],
    [store],
  );

  return {
    schemes: store.schemes,
    activeScheme,
    loading,
    saving,
    deletingId,
    createScheme,
    updateScheme,
    deleteScheme,
    selectScheme,
  };
}
