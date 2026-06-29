import { useCallback, useMemo, useState } from 'react';
import type { RequestStatus } from '../shared/types/api';
import type {
  CreateReviewQuestionSchemePayload,
  DailyReview,
  DailyReviewAnswer,
  DailyReviewDetailData,
  DailyReviewPermissions,
  DailyReviewStatus,
  ReviewQuestionScheme,
  SaveDailyReviewPayload,
  UpdateReviewQuestionSchemePayload,
} from '../shared/types/dailyReview';
import { useDailyDoc } from './vault/useDailyDoc';
import { useReviewScheme } from './vault/useReviewScheme';
import type { ReviewEntry } from '../services/vault/dailyDoc';

interface UseDailyReviewResult {
  detail: DailyReviewDetailData | null;
  schemes: ReviewQuestionScheme[];
  status: RequestStatus;
  error: string | null;
  saving: boolean;
  clearing: boolean;
  schemeSaving: boolean;
  schemeDeletingId: string | null;
  refetch: () => Promise<void>;
  refetchSchemes: () => Promise<void>;
  saveReview: (payload: SaveDailyReviewPayload) => Promise<DailyReviewDetailData | null>;
  clearReview: () => Promise<DailyReviewDetailData | null>;
  createScheme: (payload: CreateReviewQuestionSchemePayload) => Promise<ReviewQuestionScheme | null>;
  updateScheme: (payload: UpdateReviewQuestionSchemePayload) => Promise<ReviewQuestionScheme | null>;
  deleteScheme: (id: string) => Promise<boolean>;
}

/** 本地优先：复盘始终可读写（无 readonly/no_permission 演示态）。 */
const LOCAL_PERMISSIONS: DailyReviewPermissions = {
  canView: true,
  canSave: true,
  canEdit: true,
  canClear: true,
  canSelectScheme: true,
};

const NOOP = async (): Promise<void> => {
  /* 本地优先：数据由 useDailyDoc/useReviewScheme 响应式驱动，无需主动拉取 */
};

/**
 * 复盘（本地优先）：答案读写当日 Daily MD 的「今日复盘」段（经 useDailyDoc）；
 * 方案来自本地 vault 文件 Reviews/scheme.md（经 useReviewScheme）。合成 DailyReviewDetailData：
 * - review/answers 来自文件；自适应方案——若历史复盘的 questionId 全部落入某方案，则用该方案展示（历史可读）。
 * - summary/materials 来自当日本地日程/快速记录。
 * 保存/清空 → setReview 重写「今日复盘」段；方案增删改/切换 → useReviewScheme。
 */
export function useDailyReview(date: string): UseDailyReviewResult {
  const { model, setReview } = useDailyDoc(date);
  const {
    schemes,
    activeScheme,
    createScheme,
    updateScheme,
    deleteScheme,
    selectScheme,
    saving: schemeSaving,
    deletingId: schemeDeletingId,
  } = useReviewScheme();

  const [saving, setSaving] = useState(false);
  const [clearing, setClearing] = useState(false);

  const reviewEntries = useMemo<ReviewEntry[]>(() => model?.review ?? [], [model]);
  const hasContent = reviewEntries.some((entry) => entry.content.trim());
  const reviewStatus: DailyReviewStatus = hasContent ? 'completed' : 'not_started';

  // 自适应方案：历史复盘优先匹配其原始方案（questionId 全覆盖），保证历史可读
  const displayScheme = useMemo<ReviewQuestionScheme>(() => {
    if (reviewEntries.length === 0) return activeScheme;
    const ids = new Set(reviewEntries.map((entry) => entry.questionId));
    const matched = schemes.find((scheme) =>
      [...ids].every((id) => scheme.questions.some((question) => question.id === id)),
    );
    return matched ?? activeScheme;
  }, [reviewEntries, schemes, activeScheme]);

  const detail = useMemo<DailyReviewDetailData | null>(() => {
    if (!model) return null;
    const tasks = model.schedules.filter((schedule) => schedule.type !== 'note');
    const quickNotes = model.quickNotes;
    const completedCount = tasks.filter((task) => task.completed).length;
    const now = new Date().toISOString();

    const answers: DailyReviewAnswer[] = reviewEntries.map((entry) => ({
      questionId: entry.questionId,
      content: entry.content,
      updatedAt: now,
    }));

    const review: DailyReview = {
      id: `review-${date}`,
      date,
      schemeId: displayScheme.id,
      status: reviewStatus,
      answers,
      createdAt: now,
      updatedAt: now,
      completedAt: reviewStatus === 'completed' ? now : undefined,
    };

    return {
      review,
      scheme: displayScheme,
      summary: {
        taskTotal: tasks.length,
        completedCount,
        uncompletedCount: Math.max(0, tasks.length - completedCount),
        quickNoteCount: quickNotes.length,
        status: reviewStatus,
      },
      materials: { tasks, quickNotes },
      status: hasContent ? 'ok' : 'empty',
      permissions: LOCAL_PERMISSIONS,
    };
  }, [model, reviewEntries, displayScheme, date, reviewStatus, hasContent]);

  const saveReview = useCallback(
    async (payload: SaveDailyReviewPayload): Promise<DailyReviewDetailData | null> => {
      const scheme = schemes.find((item) => item.id === payload.schemeId) ?? activeScheme;
      // 按方案题目写出全部条目（空内容序列化为「暂无。」），保证结构与历史匹配
      const entries: ReviewEntry[] = scheme.questions.map((question) => ({
        questionId: question.id,
        title: question.title,
        content: payload.answers.find((answer) => answer.questionId === question.id)?.content ?? '',
      }));
      setSaving(true);
      try {
        await setReview(entries);
        if (scheme.id !== activeScheme.id) void selectScheme(scheme.id);
        return detail;
      } finally {
        setSaving(false);
      }
    },
    [schemes, activeScheme, setReview, selectScheme, detail],
  );

  const clearReview = useCallback(async (): Promise<DailyReviewDetailData | null> => {
    setClearing(true);
    try {
      await setReview([]);
      return detail;
    } finally {
      setClearing(false);
    }
  }, [setReview, detail]);

  return {
    detail,
    schemes,
    status: detail ? 'success' : 'loading',
    error: null,
    saving,
    clearing,
    schemeSaving,
    schemeDeletingId,
    refetch: NOOP,
    refetchSchemes: NOOP,
    saveReview,
    clearReview,
    createScheme,
    updateScheme,
    deleteScheme,
  };
}
