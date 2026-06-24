/**
 * Daily 实体同步引擎逻辑（docs/09 §9.3）。
 *
 * 当天未沉淀实体（settled=0）跨设备 last-write-wins 同步。仅 cloudEnabled 时由
 * syncEngine.tick 调用。游标存于 sync.db 的 sync_meta（key=daily_entity_sync_cursor）。
 *
 * 流程：
 * 1. push：查本地 4 类未沉淀实体 → 组装 payload → pushDailyEntities（服务端 LWW）
 * 2. pull：getDailyEntityChanges(cursor) → 对每条变更 LWW 写本地（远端 updatedAt > 本地才覆盖）
 * 3. 更新游标
 */
import { getDailyEntityChanges, pushDailyEntities } from './dailyEntityApi';
import type { ScheduleCategory, ScheduleType } from '../../shared/types/schedule';
import type {
  DailyFocusMirrorData,
  QuickNoteMirrorData,
  ReviewAnswerMirrorData,
  ScheduleMirrorData,
} from '../../shared/types/dailyEntitySync';
import {
  listAllUnsettledDailyFocus,
  listAllUnsettledQuickNotes,
  listAllUnsettledReviewAnswers,
  listAllUnsettledSchedules,
  upsertDailyFocus,
  upsertQuickNote,
  upsertReviewAnswer,
  upsertSchedule,
  type DailyFocusRow,
  type QuickNoteRow,
  type ReviewAnswerRow,
  type ScheduleRow,
} from './dailyEntities';
import { getMeta, setMeta } from './syncState';
import { isTauriRuntime, tauriInvoke } from './vaultFileBridge';

const CURSOR_KEY = 'daily_entity_sync_cursor';

/** 行→DTO 转换（对齐 ScheduleMirrorData）。 */
function scheduleRowToDto(r: ScheduleRow) {
  return {
    id: r.id,
    date: r.date,
    startTime: r.startTime,
    endTime: r.endTime,
    title: r.title,
    category: r.category,
    type: r.type,
    completed: r.completed,
    focus: r.focus,
    sortOrder: r.sortOrder,
    settled: r.settled,
    deleted: r.deleted,
    updatedAt: r.updatedAt,
  };
}

function quickNoteRowToDto(r: QuickNoteRow) {
  return {
    id: r.id,
    date: r.date,
    content: r.content,
    settled: r.settled,
    deleted: r.deleted,
    updatedAt: r.updatedAt,
  };
}

function reviewAnswerRowToDto(r: ReviewAnswerRow) {
  return {
    id: r.id,
    date: r.date,
    questionId: r.questionId,
    title: r.title,
    content: r.content,
    settled: r.settled,
    deleted: r.deleted,
    updatedAt: r.updatedAt,
  };
}

function dailyFocusRowToDto(r: DailyFocusRow) {
  return {
    date: r.date,
    content: r.content,
    settled: r.settled,
    deleted: false,
    updatedAt: r.updatedAt,
  };
}

/** push：本地未沉淀实体推到云端（LWW 由服务端裁决）。 */
export async function pushUnsettledEntities(root: string, deviceId: string): Promise<void> {
  const [schedules, quickNotes, reviews, focus] = await Promise.all([
    listAllUnsettledSchedules(root),
    listAllUnsettledQuickNotes(root),
    listAllUnsettledReviewAnswers(root),
    listAllUnsettledDailyFocus(root),
  ]);
  if (schedules.length === 0 && quickNotes.length === 0 && reviews.length === 0 && focus.length === 0) {
    return; // 无未沉淀数据，跳过
  }
  await pushDailyEntities({
    schedules: schedules.map(scheduleRowToDto),
    quickNotes: quickNotes.map(quickNoteRowToDto),
    reviewAnswers: reviews.map(reviewAnswerRowToDto),
    dailyFocuses: focus.map(dailyFocusRowToDto),
    deviceId,
  });
}

/**
 * pull：增量拉取远端变更，对每条 LWW 写本地（远端 updatedAt 晚于本地才覆盖）。
 * 返回最新游标。
 */
export async function pullEntityChanges(root: string): Promise<string> {
  const cursor = (await getMeta(root, CURSOR_KEY)) ?? undefined;
  const res = await getDailyEntityChanges(cursor, 200);
  if (!res.success || !res.data) {
    return cursor ?? new Date().toISOString();
  }

  const { schedules, quickNotes, reviewAnswers, dailyFocuses, nextCursor } = res.data;

  // LWW 写本地：远端 updatedAt > 本地 updatedAt 才覆盖
  for (const s of schedules) {
    await upsertScheduleIfNewer(root, s);
  }
  for (const q of quickNotes) {
    await upsertQuickNoteIfNewer(root, q);
  }
  for (const r of reviewAnswers) {
    await upsertReviewAnswerIfNewer(root, r);
  }
  for (const f of dailyFocuses) {
    await upsertDailyFocusIfNewer(root, f);
  }

  await setMeta(root, CURSOR_KEY, nextCursor);
  return nextCursor;
}

/** 单轮实体同步：push 后 pull。由 syncEngine.tick 在 cloudEnabled 时调用。 */
export async function syncDailyEntitiesOnce(root: string, deviceId: string): Promise<void> {
  await pushUnsettledEntities(root, deviceId);
  await pullEntityChanges(root);
}

// ---- LWW 写本地（先读本地 updatedAt 比较，远端更新才 upsert）----
// 非 Tauri 内存兜底：直接 upsert（dev 联调无需精确 LWW）。

async function upsertScheduleIfNewer(root: string, dto: ScheduleMirrorDto): Promise<void> {
  if (!isTauriRuntime()) {
    await upsertSchedule(root, dtoToScheduleRow(dto));
    return;
  }
  const rows = await tauriInvoke<ScheduleRow[]>('ls_list_schedules_by_date', {
    root,
    date: dto.date,
    includeDeleted: true,
  });
  const local = (rows ?? []).find((r: ScheduleRow) => r.id === dto.id);
  if (local && local.updatedAt >= dto.updatedAt) return; // 本地较新，丢弃
  await upsertSchedule(root, dtoToScheduleRow(dto));
}

async function upsertQuickNoteIfNewer(root: string, dto: QuickNoteMirrorDto): Promise<void> {
  if (!isTauriRuntime()) {
    await upsertQuickNote(root, dtoToQuickNoteRow(dto));
    return;
  }
  const rows = await tauriInvoke<QuickNoteRow[]>('ls_list_quick_notes_by_date', {
    root,
    date: dto.date,
    includeDeleted: true,
  });
  const local = (rows ?? []).find((r: QuickNoteRow) => r.id === dto.id);
  if (local && local.updatedAt >= dto.updatedAt) return;
  await upsertQuickNote(root, dtoToQuickNoteRow(dto));
}

async function upsertReviewAnswerIfNewer(root: string, dto: ReviewAnswerMirrorDto): Promise<void> {
  if (!isTauriRuntime()) {
    await upsertReviewAnswer(root, dtoToReviewAnswerRow(dto));
    return;
  }
  const rows = await tauriInvoke<ReviewAnswerRow[]>('ls_list_review_answers_by_date', {
    root,
    date: dto.date,
    includeDeleted: true,
  });
  const local = (rows ?? []).find((r: ReviewAnswerRow) => r.id === dto.id);
  if (local && local.updatedAt >= dto.updatedAt) return;
  await upsertReviewAnswer(root, dtoToReviewAnswerRow(dto));
}

async function upsertDailyFocusIfNewer(root: string, dto: DailyFocusMirrorDto): Promise<void> {
  if (!isTauriRuntime()) {
    await upsertDailyFocus(root, dto.date, dto.content);
    return;
  }
  const local = await tauriInvoke<DailyFocusRow | null>('ls_get_daily_focus', { root, date: dto.date });
  if (local && local.updatedAt >= dto.updatedAt) return;
  await upsertDailyFocus(root, dto.date, dto.content);
}

// ---- DTO → 本地 Row（用 dailyEntitySync 的 DTO 类型，category/type 窄化）----

type ScheduleMirrorDto = ScheduleMirrorData;
type QuickNoteMirrorDto = QuickNoteMirrorData;
type ReviewAnswerMirrorDto = ReviewAnswerMirrorData;
type DailyFocusMirrorDto = DailyFocusMirrorData;

function dtoToScheduleRow(dto: ScheduleMirrorDto): ScheduleRow {
  return {
    id: dto.id,
    date: dto.date,
    startTime: dto.startTime,
    endTime: dto.endTime,
    title: dto.title,
    category: dto.category as ScheduleCategory,
    type: dto.type as ScheduleType,
    completed: dto.completed,
    focus: dto.focus,
    sortOrder: dto.sortOrder,
    settled: dto.settled,
    sourceDevice: null,
    createdAt: dto.updatedAt,
    updatedAt: dto.updatedAt,
    deleted: dto.deleted,
  };
}

function dtoToQuickNoteRow(dto: QuickNoteMirrorDto): QuickNoteRow {
  return {
    id: dto.id,
    date: dto.date,
    content: dto.content,
    sourceDevice: null,
    settled: dto.settled,
    createdAt: dto.updatedAt,
    updatedAt: dto.updatedAt,
    deleted: dto.deleted,
  };
}

function dtoToReviewAnswerRow(dto: ReviewAnswerMirrorDto): ReviewAnswerRow {
  return {
    id: dto.id,
    date: dto.date,
    questionId: dto.questionId,
    title: dto.title,
    content: dto.content,
    settled: dto.settled,
    createdAt: dto.updatedAt,
    updatedAt: dto.updatedAt,
    deleted: dto.deleted,
  };
}
