/**
 * Daily 结构化实体本地真相源封装（docs/09 SQL-first + 沉淀分层）。
 *
 * 真相源 = `<vault>/.lifescale/lifescale.db`（与 sync.db 物理分离）。当天日程/快速记录/
 * 复盘答案/今日重点全在此库 CRUD，毫秒级交互。当天数据 `settled=0`；沉淀（P2）后置 1。
 *
 * 与 `syncState.ts` 同范式：Tauri 运行时走 Rust 命令，非 Tauri（浏览器 `pnpm dev`）
 * 用内存兜底保证逻辑可联调。
 *
 * 实体 ↔ 行 转换约定：
 * - `Schedule.categoryColor`：SQL 不存（category 的派生值），读出时从 `SCHEDULE_CATEGORY_COLORS` 补回
 * - `QuickNote.createdAt`：SQL 存完整 ISO（含 HH:mm:00.000），文法渲染时由 createdAt 派生 HH:mm
 */
import type { Schedule, ScheduleCategory, ScheduleType } from '../../shared/types/schedule';
import { SCHEDULE_CATEGORY_COLORS } from '../../shared/types/schedule';
import type { QuickNote } from '../../shared/types/quickNote';
import type { ReviewEntry } from './dailyDoc';
import { isTauriRuntime, tauriInvoke } from './vaultFileBridge';

// ============================ 行类型（与 Rust serde camelCase 对齐）============================

export interface ScheduleRow {
  id: string;
  date: string;
  startTime: string;
  endTime: string;
  title: string;
  category: ScheduleCategory;
  type: ScheduleType;
  completed: boolean;
  focus: boolean;
  sortOrder: number;
  settled: boolean;
  sourceDevice: string | null;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
}

export interface QuickNoteRow {
  id: string;
  date: string;
  content: string;
  sourceDevice: string | null;
  settled: boolean;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
}

export interface ReviewAnswerRow {
  id: string;
  date: string;
  questionId: string;
  title: string;
  content: string;
  settled: boolean;
  createdAt: string;
  updatedAt: string;
  deleted: boolean;
}

export interface DailyFocusRow {
  date: string;
  content: string | null;
  settled: boolean;
  updatedAt: string;
}

/** 某天全部实体聚合（hook 组装 DailyDocModel 的数据源）。 */
export interface DailyEntitiesData {
  schedules: Schedule[];
  quickNotes: QuickNote[];
  reviews: ReviewEntry[];
  focus: string | null;
}

// ============================ 实体 ↔ 行 转换 ============================

const DEFAULT_SOURCE_DEVICE = 'desktop';

function nowIso(): string {
  return new Date().toISOString();
}

export function scheduleToRow(s: Schedule): ScheduleRow {
  const now = nowIso();
  return {
    id: s.id,
    date: s.date,
    startTime: s.startTime,
    endTime: s.endTime,
    title: s.title,
    category: s.category,
    type: s.type ?? 'task',
    completed: s.completed ?? false,
    focus: s.focus ?? false,
    sortOrder: s.sortOrder ?? 0,
    settled: false, // 当天写入恒为未沉淀；沉淀时由 mark_*_settled 批量改
    sourceDevice: DEFAULT_SOURCE_DEVICE,
    createdAt: s.createdAt ?? now,
    updatedAt: now,
    deleted: false,
  };
}

export function rowToSchedule(r: ScheduleRow): Schedule {
  return {
    id: r.id,
    date: r.date,
    startTime: r.startTime,
    endTime: r.endTime,
    title: r.title,
    category: r.category,
    categoryColor: SCHEDULE_CATEGORY_COLORS[r.category],
    type: r.type,
    completed: r.completed,
    focus: r.focus,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  };
}

export function quickNoteToRow(q: QuickNote): QuickNoteRow {
  const now = nowIso();
  return {
    id: q.id,
    date: q.date,
    content: q.content,
    sourceDevice: DEFAULT_SOURCE_DEVICE,
    settled: false,
    createdAt: q.createdAt,
    updatedAt: now,
    deleted: q.status === 'deleted',
  };
}

export function rowToQuickNote(r: QuickNoteRow): QuickNote {
  return {
    id: r.id,
    date: r.date,
    content: r.content,
    sourceDevice: DEFAULT_SOURCE_DEVICE,
    status: r.deleted ? 'deleted' : 'active',
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  };
}

export function reviewEntryToRow(r: ReviewEntry, date: string): ReviewAnswerRow {
  const now = nowIso();
  return {
    id: r.questionId, // 复盘答案以 questionId 为身份（一题一条）
    date,
    questionId: r.questionId,
    title: r.title,
    content: r.content,
    settled: false,
    createdAt: now,
    updatedAt: now,
    deleted: false,
  };
}

export function rowToReviewEntry(r: ReviewAnswerRow): ReviewEntry {
  return {
    questionId: r.questionId,
    title: r.title,
    content: r.content,
  };
}

// ============================ 非 Tauri 内存兜底 ============================
// keyed by `${root}:${date}`，存当天全量实体；复盘方案按 id 存全量。

interface MemoryDay {
  schedules: Map<string, Schedule>;
  quickNotes: Map<string, QuickNote>;
  reviews: Map<string, ReviewEntry>;
  focus: string | null;
}
const memoryDays = new Map<string, MemoryDay>();
/** 沉淀记录内存兜底（keyed by `${root}:${date}`）。 */
const memorySettlements = new Map<string, SettlementRow>();

function memDay(root: string, date: string): MemoryDay {
  const key = `${root}:${date}`;
  let day = memoryDays.get(key);
  if (!day) {
    day = { schedules: new Map(), quickNotes: new Map(), reviews: new Map(), focus: null };
    memoryDays.set(key, day);
  }
  return day;
}

// ============================ 读取：loadDailyEntities ============================

export async function loadDailyEntities(root: string, date: string): Promise<DailyEntitiesData> {
  if (!isTauriRuntime()) {
    const day = memDay(root, date);
    return {
      schedules: Array.from(day.schedules.values()).sort(
        (a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0) || a.startTime.localeCompare(b.startTime),
      ),
      quickNotes: Array.from(day.quickNotes.values()).sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
      reviews: Array.from(day.reviews.values()),
      focus: day.focus,
    };
  }
  const [schedules, quickNotes, reviews, focus] = await Promise.all([
    tauriInvoke<ScheduleRow[]>('ls_list_schedules_by_date', { root, date, includeDeleted: false }),
    tauriInvoke<QuickNoteRow[]>('ls_list_quick_notes_by_date', { root, date, includeDeleted: false }),
    tauriInvoke<ReviewAnswerRow[]>('ls_list_review_answers_by_date', { root, date, includeDeleted: false }),
    tauriInvoke<DailyFocusRow | null>('ls_get_daily_focus', { root, date }),
  ]);
  return {
    schedules: schedules.map(rowToSchedule),
    quickNotes: quickNotes.map(rowToQuickNote),
    reviews: reviews.map(rowToReviewEntry),
    focus: focus?.content ?? null,
  };
}

// ============================ 批量替换（hook mutate 的核心写路径）============================
// 策略：先软删当天该类全部实体（墓碑保留供同步/对账），再批量 upsert 新集合。
// 由调用方 runChained 串行保证一致性。now 由调用方传入以便同批时间戳一致。

export async function batchReplaceSchedules(root: string, date: string, schedules: Schedule[]): Promise<void> {
  const now = nowIso();
  if (!isTauriRuntime()) {
    const day = memDay(root, date);
    day.schedules.clear();
    for (const s of schedules) day.schedules.set(s.id, s);
    return;
  }
  await tauriInvoke<void>('ls_soft_delete_schedules_by_date', { root, date, now });
  for (const s of schedules) {
    await tauriInvoke<void>('ls_upsert_schedule', { root, schedule: scheduleToRow(s) });
  }
}

export async function batchReplaceQuickNotes(root: string, date: string, quickNotes: QuickNote[]): Promise<void> {
  const now = nowIso();
  if (!isTauriRuntime()) {
    const day = memDay(root, date);
    day.quickNotes.clear();
    for (const q of quickNotes) day.quickNotes.set(q.id, q);
    return;
  }
  await tauriInvoke<void>('ls_soft_delete_quick_notes_by_date', { root, date, now });
  for (const q of quickNotes) {
    await tauriInvoke<void>('ls_upsert_quick_note', { root, quickNote: quickNoteToRow(q) });
  }
}

export async function batchReplaceReviews(root: string, date: string, reviews: ReviewEntry[]): Promise<void> {
  const now = nowIso();
  if (!isTauriRuntime()) {
    const day = memDay(root, date);
    day.reviews.clear();
    for (const r of reviews) day.reviews.set(r.questionId, r);
    return;
  }
  await tauriInvoke<void>('ls_soft_delete_review_answers_by_date', { root, date, now });
  for (const r of reviews) {
    await tauriInvoke<void>('ls_upsert_review_answer', { root, answer: reviewEntryToRow(r, date) });
  }
}

export async function upsertDailyFocus(root: string, date: string, content: string | null): Promise<void> {
  const now = nowIso();
  if (!isTauriRuntime()) {
    memDay(root, date).focus = content;
    return;
  }
  await tauriInvoke<void>('ls_upsert_daily_focus', {
    root,
    focus: { date, content, settled: false, updatedAt: now } satisfies DailyFocusRow,
  });
}

/**
 * 单条实体 upsert（P4 pull 写本地用，直接走 Rust ls_upsert_* 命令，保留传入的 settled/updatedAt）。
 * 内存兜底：写入当天 Map。
 */
export async function upsertSchedule(root: string, row: ScheduleRow): Promise<void> {
  if (!isTauriRuntime()) {
    memDay(root, row.date).schedules.set(row.id, rowToSchedule(row));
    return;
  }
  await tauriInvoke<void>('ls_upsert_schedule', { root, schedule: row });
}

export async function upsertQuickNote(root: string, row: QuickNoteRow): Promise<void> {
  if (!isTauriRuntime()) {
    memDay(root, row.date).quickNotes.set(row.id, rowToQuickNote(row));
    return;
  }
  await tauriInvoke<void>('ls_upsert_quick_note', { root, quickNote: row });
}

export async function upsertReviewAnswer(root: string, row: ReviewAnswerRow): Promise<void> {
  if (!isTauriRuntime()) {
    memDay(root, row.date).reviews.set(row.questionId, rowToReviewEntry(row));
    return;
  }
  await tauriInvoke<void>('ls_upsert_review_answer', { root, answer: row });
}

// ============================ 沉淀（docs/09 第七章）============================

/** 沉淀产物目录（docs/09 §6.1.3 与遗留的 Daily/ 分离）。 */
export const SETTLEMENT_VAULT_DIR = 'Notes/Daily';

/** 沉淀产物路径：Notes/Daily/<date>.md（相对 vault 根）。 */
export function settlementVaultPath(date: string): string {
  return `${SETTLEMENT_VAULT_DIR}/${date}.md`;
}

/** 沉淀记录行（与 Rust serde camelCase 对齐）。 */
export interface SettlementRow {
  date: string;
  mdContentHash: string;
  mdVaultPath: string;
  settledAt: string;
  /** 'manual' | 'lazy-backfill' | device_id */
  settledBy: string;
}

/**
 * 标记当天 4 类实体 settled=1（docs/09 §7.2 第 5 步）。now 统一取一次保证同批时间戳一致。
 * 内存兜底：no-op（浏览器 dev 联调无需追踪 settled，真实状态在 Rust）。
 */
export async function markDailyEntitiesSettled(root: string, date: string): Promise<void> {
  const now = nowIso();
  if (!isTauriRuntime()) return;
  await Promise.all([
    tauriInvoke<void>('ls_mark_schedules_settled_by_date', { root, date, now }),
    tauriInvoke<void>('ls_mark_quick_notes_settled_by_date', { root, date, now }),
    tauriInvoke<void>('ls_mark_review_answers_settled_by_date', { root, date, now }),
    tauriInvoke<void>('ls_mark_daily_focus_settled_by_date', { root, date, now }),
  ]);
}

export async function getSettlement(root: string, date: string): Promise<SettlementRow | null> {
  if (!isTauriRuntime()) return memorySettlements.get(`${root}:${date}`) ?? null;
  return tauriInvoke<SettlementRow | null>('ls_get_settlement', { root, date });
}

export async function upsertSettlement(root: string, row: SettlementRow): Promise<void> {
  if (!isTauriRuntime()) {
    memorySettlements.set(`${root}:${row.date}`, row);
    return;
  }
  await tauriInvoke<void>('ls_upsert_settlement', { root, settlement: row });
}

/**
 * 列出所有「过去日期且未沉淀」的日期（docs/09 §7.3 惰性补沉淀扫描）。
 * 内存兜底：返回空（浏览器 dev 无真实未沉淀数据）。
 */
export async function listUnsettledPastDates(root: string, today: string): Promise<string[]> {
  if (!isTauriRuntime()) return [];
  return tauriInvoke<string[]>('ls_list_unsettled_past_dates', { root, today });
}

/**
 * 列出某月有沉淀记录的日期（docs/09 §8 月历标记 settled 驱动）。
 * yearMonth = 'YYYY-MM'。内存兜底：返回空。
 */
export async function listSettledDatesInMonth(root: string, yearMonth: string): Promise<string[]> {
  if (!isTauriRuntime()) return [];
  return tauriInvoke<string[]>('ls_list_settled_dates_in_month', { root, yearMonth });
}

/**
 * 列出全部未沉淀实体（settled=0 AND deleted=0），供 P4 跨设备 push（docs/09 §9.3）。
 * 内存兜底：返回空（浏览器 dev 无真实未沉淀数据）。
 */
export async function listAllUnsettledSchedules(root: string): Promise<ScheduleRow[]> {
  if (!isTauriRuntime()) return [];
  return tauriInvoke<ScheduleRow[]>('ls_list_all_unsettled_schedules', { root });
}

export async function listAllUnsettledQuickNotes(root: string): Promise<QuickNoteRow[]> {
  if (!isTauriRuntime()) return [];
  return tauriInvoke<QuickNoteRow[]>('ls_list_all_unsettled_quick_notes', { root });
}

export async function listAllUnsettledReviewAnswers(root: string): Promise<ReviewAnswerRow[]> {
  if (!isTauriRuntime()) return [];
  return tauriInvoke<ReviewAnswerRow[]>('ls_list_all_unsettled_review_answers', { root });
}

export async function listAllUnsettledDailyFocus(root: string): Promise<DailyFocusRow[]> {
  if (!isTauriRuntime()) return [];
  return tauriInvoke<DailyFocusRow[]>('ls_list_all_unsettled_daily_focus', { root });
}
