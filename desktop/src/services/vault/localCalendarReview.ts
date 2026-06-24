import dayjs from 'dayjs';
import type { ApiResponse } from '../../shared/types/api';
import type {
  CalendarDateMarker,
  CalendarDayDetail,
  CalendarDayOverview,
  CalendarMonthOverview,
  CalendarReviewPermissions,
  CalendarReviewStatus,
  CalendarWeekOverview,
} from '../../shared/types/calendarReview';
import type { DailyMarkdownDocument, DailyMarkdownPermissions } from '../../shared/types/dailyMarkdown';
import type {
  DailyReview,
  DailyReviewAnswer,
  DailyReviewPermissions,
  DailyReviewStatus,
  ReviewQuestionScheme,
} from '../../shared/types/dailyReview';
import type { QuickNote } from '../../shared/types/quickNote';
import { getWeekday } from '../../shared/utils/date';
import { DEFAULT_DAILY_SUBDIRECTORY, dailyRelativePath, joinPath } from '../../shared/utils/markdownPaths';
import {
  createEmptyDailyDoc,
  parseDailyDoc,
  serializeCleanDailyDoc,
  serializeDailyDoc,
  type DailyDocModel,
} from './dailyDoc';
import { DEFAULT_REVIEW_SCHEME_STORE, SCHEME_VAULT_PATH, parseSchemeDoc } from './reviewScheme';

interface LocalCalendarReviewDeps {
  root: string | null;
  dailySubdir?: string;
  listFiles: () => Promise<readonly { path: string }[]>;
  readFile: (vaultPath: string) => Promise<string>;
  writeFile: (vaultPath: string, content: string) => Promise<void>;
}

const EMPTY_MARKER: CalendarDateMarker = { type: 'empty', label: '无数据', color: '#cbd5e1' };
const MARKERS = {
  schedule: '#2f6df6',
  quickNote: '#8b5cf6',
  reviewCompleted: '#22c55e',
  reviewPending: '#f59e0b',
} as const;

function ok<T>(data: T, message = 'ok'): ApiResponse<T> {
  return { code: 200, success: true, message, data };
}

function dailySubdir(deps: LocalCalendarReviewDeps): string {
  return deps.dailySubdir?.trim() || DEFAULT_DAILY_SUBDIRECTORY;
}

function titleForDate(date: string): string {
  return `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`;
}

function permissions(root: string | null): CalendarReviewPermissions {
  const hasRoot = Boolean(root);
  return {
    canView: true,
    canBackfillQuickNote: hasRoot,
    canEditReview: hasRoot,
    canViewMarkdown: true,
    canEditMarkdown: hasRoot,
    reason: hasRoot ? undefined : '请先选择本地工作区',
  };
}

function markdownPermissions(root: string | null): DailyMarkdownPermissions {
  const hasRoot = Boolean(root);
  return {
    canView: true,
    canEdit: hasRoot,
    canSave: hasRoot,
    canChooseFolder: true,
    canWriteToDisk: hasRoot,
    reason: hasRoot ? undefined : '请先选择本地工作区',
  };
}

function reviewPermissions(root: string | null): DailyReviewPermissions {
  const hasRoot = Boolean(root);
  return {
    canView: true,
    canSave: hasRoot,
    canEdit: hasRoot,
    canClear: hasRoot,
    canSelectScheme: hasRoot,
    reason: hasRoot ? undefined : '请先选择本地工作区',
  };
}

async function readRaw(date: string, deps: LocalCalendarReviewDeps): Promise<string> {
  return deps.readFile(dailyRelativePath(date, dailySubdir(deps)));
}

async function readModel(date: string, deps: LocalCalendarReviewDeps): Promise<{ raw: string; model: DailyDocModel }> {
  const raw = await readRaw(date, deps);
  if (!raw.trim()) {
    return { raw, model: createEmptyDailyDoc(titleForDate(date)) };
  }
  return { raw, model: parseDailyDoc(raw, { date }).model };
}

async function readActiveScheme(deps: LocalCalendarReviewDeps): Promise<ReviewQuestionScheme> {
  const fallback = DEFAULT_REVIEW_SCHEME_STORE.schemes.find(
    (scheme) => scheme.id === DEFAULT_REVIEW_SCHEME_STORE.activeSchemeId,
  ) ?? DEFAULT_REVIEW_SCHEME_STORE.schemes[0];
  try {
    const raw = await deps.readFile(SCHEME_VAULT_PATH);
    const store = parseSchemeDoc(raw);
    return store.schemes.find((scheme) => scheme.id === store.activeSchemeId) ?? fallback;
  } catch {
    return fallback;
  }
}

function quickNoteTime(note: QuickNote): string {
  const match = note.createdAt.match(/T(\d{2}:\d{2})/);
  return match?.[1] ?? '00:00';
}

function reviewAnswers(model: DailyDocModel, scheme: ReviewQuestionScheme): DailyReviewAnswer[] {
  const byId = new Map(model.review.map((entry) => [entry.questionId, entry.content]));
  const byTitle = new Map(model.review.map((entry) => [entry.title, entry.content]));
  const now = new Date().toISOString();
  return scheme.questions.map((question) => ({
    questionId: question.id,
    content: byId.get(question.id) ?? byTitle.get(question.title) ?? '',
    updatedAt: now,
  }));
}

function reviewStatus(answers: DailyReviewAnswer[]): DailyReviewStatus {
  return answers.some((answer) => answer.content.trim()) ? 'completed' : 'not_started';
}

function buildMarkdownDocument(
  date: string,
  raw: string,
  deps: LocalCalendarReviewDeps,
  content = raw,
): DailyMarkdownDocument {
  const subdir = dailySubdir(deps);
  const relativePath = dailyRelativePath(date, subdir);
  const fallbackContent = content.trim() ? content : serializeDailyDoc(createEmptyDailyDoc(titleForDate(date)));
  const updatedAt = new Date().toISOString();
  return {
    date,
    title: titleForDate(date),
    fileName: `${date}.md`,
    relativePath,
    absolutePath: deps.root ? joinPath(deps.root, relativePath) : relativePath,
    content: fallbackContent,
    updatedAt,
    savedAt: raw.trim() ? updatedAt : undefined,
    status: raw.trim() ? 'ok' : 'empty',
    permissions: markdownPermissions(deps.root),
  };
}

function markersFor(model: DailyDocModel): CalendarDateMarker[] {
  const markers: CalendarDateMarker[] = [];
  const reviewDone = model.review.some((entry) => entry.content.trim());
  if (model.schedules.length > 0) {
    markers.push({ type: 'schedule', label: '有日程', color: MARKERS.schedule, count: model.schedules.length });
  }
  if (model.quickNotes.length > 0) {
    markers.push({ type: 'quick_note', label: '有快速记录', color: MARKERS.quickNote, count: model.quickNotes.length });
  }
  if (reviewDone) {
    markers.push({ type: 'review_completed', label: '已复盘', color: MARKERS.reviewCompleted, count: 1 });
  } else if (model.schedules.length > 0 || model.quickNotes.length > 0) {
    markers.push({ type: 'review_pending', label: '未复盘', color: MARKERS.reviewPending, count: 1 });
  }
  return markers.length ? markers : [EMPTY_MARKER];
}

function overviewFromModel(
  date: string,
  raw: string,
  model: DailyDocModel,
  deps: LocalCalendarReviewDeps,
): CalendarDayOverview {
  const markers = markersFor(model);
  const hasContent = raw.trim().length > 0 || markers.some((marker) => marker.type !== 'empty');
  return {
    date,
    weekday: getWeekday(date),
    lunarLabel: '',
    markers,
    scheduleCount: model.schedules.length,
    quickNoteCount: model.quickNotes.length,
    schedulePreview: model.schedules.slice(0, 3).map((schedule) => ({
      id: schedule.id,
      title: schedule.title,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      category: schedule.category,
    })),
    quickNotePreview: model.quickNotes.slice(0, 3).map((note) => ({
      id: note.id,
      time: quickNoteTime(note),
      content: note.content,
    })),
    reviewStatus: model.review.some((entry) => entry.content.trim()) ? 'completed' : 'not_started',
    markdownStatus: raw.trim() ? 'ok' : 'empty',
    status: hasContent ? 'ok' : 'empty',
    permissions: permissions(deps.root),
  };
}

async function dayOverview(date: string, deps: LocalCalendarReviewDeps): Promise<CalendarDayOverview> {
  const { raw, model } = await readModel(date, deps);
  return overviewFromModel(date, raw, model, deps);
}

export async function getLocalCalendarDayDetail(
  date: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<CalendarDayDetail>> {
  const [{ raw, model }, scheme] = await Promise.all([readModel(date, deps), readActiveScheme(deps)]);
  const answers = reviewAnswers(model, scheme);
  const status = reviewStatus(answers);
  const now = new Date().toISOString();
  const review: DailyReview = {
    id: `review-${date}`,
    date,
    schemeId: scheme.id,
    status,
    answers,
    createdAt: now,
    updatedAt: now,
    completedAt: status === 'completed' ? now : undefined,
  };
  const overview = overviewFromModel(date, raw, model, deps);
  const data: CalendarDayDetail = {
    overview,
    schedules: model.schedules,
    quickNotes: model.quickNotes,
    review: {
      review,
      scheme,
      permissions: reviewPermissions(deps.root),
    },
    markdown: buildMarkdownDocument(date, raw, deps, raw),
    permissions: permissions(deps.root),
    status: overview.status as CalendarReviewStatus,
  };
  return ok(data);
}

export async function getLocalCalendarWeekOverview(
  startDate: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<CalendarWeekOverview>> {
  const start = dayjs(startDate);
  const list = await Promise.all(
    Array.from({ length: 7 }, (_, index) => dayOverview(start.add(index, 'day').format('YYYY-MM-DD'), deps)),
  );
  const data: CalendarWeekOverview = {
    list,
    total: list.length,
    pageNo: 1,
    pageSize: list.length,
    startDate,
    endDate: start.add(6, 'day').format('YYYY-MM-DD'),
    status: list.some((day) => day.status === 'ok') ? 'ok' : 'empty',
    permissions: permissions(deps.root),
  };
  return ok(data);
}

export async function getLocalCalendarMonthOverview(
  month: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<CalendarMonthOverview>> {
  const start = dayjs(`${month}-01`);
  const daysInMonth = start.daysInMonth();
  const list = await Promise.all(
    Array.from({ length: daysInMonth }, (_, index) => dayOverview(start.date(index + 1).format('YYYY-MM-DD'), deps)),
  );
  const data: CalendarMonthOverview = {
    list,
    total: list.length,
    pageNo: 1,
    pageSize: list.length,
    month,
    status: list.some((day) => day.status === 'ok') ? 'ok' : 'empty',
    permissions: permissions(deps.root),
  };
  return ok(data);
}

export async function appendLocalQuickNote(
  date: string,
  content: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<QuickNote>> {
  const { raw, model } = await readModel(date, deps);
  const now = dayjs();
  const note: QuickNote = {
    id: typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
      ? crypto.randomUUID()
      : `qn-${Date.now()}`,
    date,
    content,
    sourceDevice: 'desktop',
    status: 'active',
    createdAt: `${date}T${now.format('HH:mm')}:00.000`,
    updatedAt: new Date().toISOString(),
  };
  const next = { ...model, quickNotes: [...model.quickNotes, note] };
  await deps.writeFile(dailyRelativePath(date, dailySubdir(deps)), serializeDailyDoc(next));
  return ok(note, raw.trim() ? '记录已保存' : '记录已保存，并创建当日 Markdown');
}

export async function getLocalDailyMarkdownDocument(
  date: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<DailyMarkdownDocument>> {
  const raw = await readRaw(date, deps);
  return ok(buildMarkdownDocument(date, raw, deps, raw));
}

export async function saveLocalDailyMarkdownSource(
  date: string,
  content: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<DailyMarkdownDocument>> {
  const path = dailyRelativePath(date, dailySubdir(deps));
  await deps.writeFile(path, content);
  return ok(buildMarkdownDocument(date, content, deps, content), 'Markdown 源码已保存');
}

// ============================ 对账详情（docs/09 P3 SQL 归档优先）============================

import type { HistoryDayStatus } from './historyReconcile';

/** 对账后的日详情（CalendarDayDetail + 对账状态，供 UI 决定是否提示）。 */
export type ReconciledDayDetail = CalendarDayDetail & {
  reconciliationStatus: HistoryDayStatus;
};

/**
 * 对账详情（docs/09 §8.1 SQL 归档优先）：详情数据源恒从 SQL 归档读取，对账状态
 * 由 settlement hash vs 磁盘 .md 判定。比 getLocalCalendarDayDetail（读旧 Daily/.md）
 * 更适配 P1/P2 后的 SQL-first 架构。
 */
export async function getReconciledDayDetail(
  date: string,
  deps: LocalCalendarReviewDeps,
): Promise<ApiResponse<ReconciledDayDetail>> {
  if (!deps.root) {
    return ok(emptyReconciledDetail(date), '本地工作区未设置');
  }

  const { openHistoryDay } = await import('./historyReconcile');
  const result = await openHistoryDay(deps.root, date);

  // 详情恒从 SQL 归档组装（result.sqlEntities）；empty 态用空模型
  const entities = result.sqlEntities ?? { schedules: [], quickNotes: [], reviews: [], focus: null };
  const model: DailyDocModel = {
    title: `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`,
    focus: entities.focus,
    schedules: entities.schedules,
    quickNotes: entities.quickNotes,
    review: entities.reviews,
  };

  // 派生 markdown raw（供 overview.markdownStatus 与 markdown 字段；优先磁盘 .md，否则 serialize）
  const raw = result.diskMd ?? (result.status === 'empty' ? '' : serializeCleanDailyDoc(model));

  const scheme = await readActiveScheme(deps);
  const answers = reviewAnswers(model, scheme);
  const status = reviewStatus(answers);
  const now = new Date().toISOString();
  const review: DailyReview = {
    id: `review-${date}`,
    date,
    schemeId: scheme.id,
    status,
    answers,
    createdAt: now,
    updatedAt: now,
    completedAt: status === 'completed' ? now : undefined,
  };
  const overview = overviewFromModel(date, raw, model, deps);

  const data: ReconciledDayDetail = {
    overview,
    schedules: model.schedules,
    quickNotes: model.quickNotes,
    review: { review, scheme, permissions: reviewPermissions(deps.root) },
    markdown: buildMarkdownDocument(date, raw, deps, raw),
    permissions: permissions(deps.root),
    status: overview.status as CalendarReviewStatus,
    reconciliationStatus: result.status,
  };
  return ok(data);
}

function emptyReconciledDetail(date: string): ReconciledDayDetail {
  const model = createEmptyDailyDoc(`${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`);
  const nullDeps: LocalCalendarReviewDeps = {
    root: null,
    dailySubdir: '',
    listFiles: () => Promise.resolve([]),
    readFile: () => Promise.resolve(''),
    writeFile: () => Promise.resolve(),
  };
  const overview = overviewFromModel(date, '', model, nullDeps);
  const fallbackScheme =
    DEFAULT_REVIEW_SCHEME_STORE.schemes.find((s) => s.id === DEFAULT_REVIEW_SCHEME_STORE.activeSchemeId) ??
    DEFAULT_REVIEW_SCHEME_STORE.schemes[0];
  const review: DailyReview = {
    id: `review-${date}`,
    date,
    schemeId: fallbackScheme.id,
    status: 'not_started',
    answers: [],
    createdAt: '',
    updatedAt: '',
  };
  return {
    overview,
    schedules: [],
    quickNotes: [],
    review: { review, scheme: fallbackScheme, permissions: reviewPermissions(null) },
    markdown: buildMarkdownDocument(date, '', nullDeps, ''),
    permissions: permissions(null),
    status: 'empty',
    reconciliationStatus: 'empty',
  };
}
