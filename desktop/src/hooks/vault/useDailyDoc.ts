import { useCallback, useEffect, useRef, useState } from 'react';
import dayjs from 'dayjs';
import {
  createEmptyDailyDoc,
  parseDailyDoc,
  serializeCleanDailyDoc,
  type DailyDocModel,
  type ReviewEntry,
} from '../../services/vault/dailyDoc';
import {
  batchReplaceQuickNotes,
  batchReplaceReviews,
  batchReplaceSchedules,
  loadDailyEntities,
  upsertDailyFocus,
} from '../../services/vault/dailyEntities';
import { runChained } from '../../services/vault/mutateChain';
import { getWeekday } from '../../shared/utils/date';
import type { Schedule } from '../../shared/types/schedule';
import type { QuickNote } from '../../shared/types/quickNote';
import { useVaultSync } from '../useVaultSync';

function getTitle(date: string): string {
  return `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`;
}

interface UseDailyDocResult {
  model: DailyDocModel | null;
  loading: boolean;
  setSchedules: (next: Schedule[] | ((prev: Schedule[]) => Schedule[])) => Promise<void>;
  setQuickNotes: (next: QuickNote[] | ((prev: QuickNote[]) => QuickNote[])) => Promise<void>;
  setFocusText: (text: string | null) => Promise<void>;
  setReview: (next: ReviewEntry[] | ((prev: ReviewEntry[]) => ReviewEntry[])) => Promise<void>;
  rawContent: string;
  setRawContent: (next: string) => Promise<void>;
}

/**
 * 每日文档中心结构化 store（docs/09 SQL-first + 沉淀分层）。
 *
 * 真相源 = 本地 SQLite `lifescale.db`（via dailyEntities → Tauri）。当天日程/快速记录/
 * 复盘答案/今日重点全在此库 CRUD，毫秒级交互。**当天不写 `Daily/*.md`**（docs/09 §5.3：
 * 当天不沉淀 = 笔记侧无当天文档；.md 由 P2 沉淀动作生成）。
 *
 * 段更新器改自己那段 → 基于 SQL 最新实体的「读-改-批量替换」→ runChained 按 date 串行
 * 防多 hook 实例并发覆盖。rawContent 从实体重新 serializeClean 派生，仅供编辑器显示
 * （P1 阶段当天无磁盘 .md 可镜像）。
 */
export function useDailyDoc(date: string): UseDailyDocResult {
  const { vaultRoot } = useVaultSync();

  const [model, setModel] = useState<DailyDocModel | null>(null);
  const [loading, setLoading] = useState(false);
  const [rawContent, setRawContentState] = useState('');
  const dateRef = useRef(date);
  dateRef.current = date;
  const modelRef = useRef<DailyDocModel | null>(null);
  modelRef.current = model;

  /** 从 SQL 实体组装 DailyDocModel + 派生 rawContent（纯净文法快照）。 */
  const assembleFromEntities = useCallback((entities: {
    schedules: Schedule[];
    quickNotes: QuickNote[];
    reviews: ReviewEntry[];
    focus: string | null;
  }): DailyDocModel => {
    const next: DailyDocModel = {
      title: getTitle(dateRef.current),
      focus: entities.focus,
      schedules: entities.schedules,
      quickNotes: entities.quickNotes,
      review: entities.reviews,
    };
    setRawContentState(serializeCleanDailyDoc(next));
    return next;
  }, []);

  const readAndParse = useCallback(async () => {
    if (!vaultRoot) {
      setModel(null);
      setRawContentState('');
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const entities = await loadDailyEntities(vaultRoot, dateRef.current);
      if (
        entities.schedules.length === 0 &&
        entities.quickNotes.length === 0 &&
        entities.reviews.length === 0 &&
        entities.focus === null
      ) {
        const empty = createEmptyDailyDoc(getTitle(dateRef.current));
        setModel(empty);
        setRawContentState(serializeCleanDailyDoc(empty));
      } else {
        setModel(assembleFromEntities(entities));
      }
    } finally {
      setLoading(false);
    }
  }, [vaultRoot, assembleFromEntities]);

  useEffect(() => {
    void readAndParse();
  }, [readAndParse]);

  /**
   * 基于 SQL 最新实体的「读-改-批量替换」（全局按 date 串行，防多 hook 实例互相覆盖），
   * 返回写入结束的 promise。当天只落 SQL，不写 .md（沉淀 P2 才生成 .md）。
   */
  const mutate = useCallback(
    (apply: (base: DailyDocModel) => DailyDocModel): Promise<void> => {
      if (!vaultRoot) return Promise.resolve();
      const dateKey = `daily:${dateRef.current}`;
      return runChained(dateKey, async () => {
        const entities = await loadDailyEntities(vaultRoot, dateRef.current);
        const base =
          entities.schedules.length === 0 &&
          entities.quickNotes.length === 0 &&
          entities.reviews.length === 0 &&
          entities.focus === null
            ? createEmptyDailyDoc(getTitle(dateRef.current))
            : {
                title: getTitle(dateRef.current),
                focus: entities.focus,
                schedules: entities.schedules,
                quickNotes: entities.quickNotes,
                review: entities.reviews,
              };
        const next = apply(base);
        setModel(next);
        setRawContentState(serializeCleanDailyDoc(next));
        await Promise.all([
          batchReplaceSchedules(vaultRoot, dateRef.current, next.schedules),
          batchReplaceQuickNotes(vaultRoot, dateRef.current, next.quickNotes),
          batchReplaceReviews(vaultRoot, dateRef.current, next.review),
          upsertDailyFocus(vaultRoot, dateRef.current, next.focus),
        ]);
      });
    },
    [vaultRoot],
  );

  const setSchedules = useCallback(
    (next: Schedule[] | ((prev: Schedule[]) => Schedule[])): Promise<void> =>
      mutate((base) => ({
        ...base,
        schedules: typeof next === 'function' ? next(base.schedules) : next,
      })),
    [mutate],
  );

  const setQuickNotes = useCallback(
    (next: QuickNote[] | ((prev: QuickNote[]) => QuickNote[])): Promise<void> =>
      mutate((base) => ({
        ...base,
        quickNotes: typeof next === 'function' ? next(base.quickNotes) : next,
      })),
    [mutate],
  );

  const setFocusText = useCallback(
    (text: string | null): Promise<void> => mutate((base) => ({ ...base, focus: text })),
    [mutate],
  );

  const setReview = useCallback(
    (next: ReviewEntry[] | ((prev: ReviewEntry[]) => ReviewEntry[])): Promise<void> =>
      mutate((base) => ({
        ...base,
        review: typeof next === 'function' ? next(base.review) : next,
      })),
    [mutate],
  );

  /**
   * raw 整文写：parse 成实体再落 SQL（用户粘贴整文时解析）。rawContent 状态从实体重新
   * serializeClean 派生，不镜像磁盘 .md（当天无 .md）。P1 阶段保留此入口供 ReviewPage
   * 源码视图/外部粘贴使用。
   */
  const setRawContent = useCallback(
    (next: string): Promise<void> => {
      if (!vaultRoot) return Promise.resolve();
      const dateKey = `daily:${dateRef.current}`;
      return runChained(dateKey, async () => {
        const base =
          modelRef.current ??
          createEmptyDailyDoc(getTitle(dateRef.current));
        const parsedModel: DailyDocModel = { ...base, ...fromRawToEntities(next, dateRef.current) };
        setModel(parsedModel);
        setRawContentState(next);
        await Promise.all([
          batchReplaceSchedules(vaultRoot, dateRef.current, parsedModel.schedules),
          batchReplaceQuickNotes(vaultRoot, dateRef.current, parsedModel.quickNotes),
          batchReplaceReviews(vaultRoot, dateRef.current, parsedModel.review),
          upsertDailyFocus(vaultRoot, dateRef.current, parsedModel.focus),
        ]);
      });
    },
    [vaultRoot],
  );

  return {
    model,
    loading,
    setSchedules,
    setQuickNotes,
    setFocusText,
    setReview,
    rawContent,
    setRawContent,
  };
}

/**
 * 把 raw markdown 拆成实体段（宽松解析，容错无注释/带注释/占位文案）。
 * 用 setRawContent 粘贴整文时把内容散落到 schedules/quickNotes/review/focus。
 */
function fromRawToEntities(md: string, date: string): {
  focus: string | null;
  schedules: Schedule[];
  quickNotes: QuickNote[];
  review: ReviewEntry[];
} {
  // parseDailyDoc 容错带注释与无注释两种文法（种子/老文件带注释，纯净文法无注释）。
  const { model } = parseDailyDoc(md, { date });
  return {
    focus: model.focus,
    schedules: model.schedules,
    quickNotes: model.quickNotes,
    review: model.review,
  };
}
