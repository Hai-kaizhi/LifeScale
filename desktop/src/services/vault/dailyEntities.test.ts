import { describe, it, expect, beforeEach } from 'vitest';
import type { Schedule } from '../../shared/types/schedule';
import { SCHEDULE_CATEGORY_COLORS } from '../../shared/types/schedule';
import type { QuickNote } from '../../shared/types/quickNote';
import {
  batchReplaceQuickNotes,
  batchReplaceReviews,
  batchReplaceSchedules,
  loadDailyEntities,
  quickNoteToRow,
  reviewEntryToRow,
  rowToQuickNote,
  rowToReviewEntry,
  rowToSchedule,
  scheduleToRow,
  upsertDailyFocus,
} from './dailyEntities';
import type { ReviewEntry } from './dailyDoc';

/**
 * dailyEntities 实体↔行转换 + 非 Tauri 内存兜底往返测试。
 * vitest 跑在 Node（非 Tauri 运行时），isTauriRuntime() 返回 false，走内存兜底分支。
 */
const ROOT = '/test/vault';
const DATE = '2026-06-23';

function makeSchedule(over: Partial<Schedule> = {}): Schedule {
  return {
    id: 'sch-1',
    title: '同步联调',
    completed: false,
    category: '工作',
    categoryColor: SCHEDULE_CATEGORY_COLORS['工作'],
    type: 'task',
    focus: false,
    sortOrder: 0,
    startTime: '09:00',
    endTime: '10:00',
    date: DATE,
    createdAt: '2026-06-23T09:00:00.000',
    updatedAt: '2026-06-23T09:00:00.000',
    ...over,
  };
}

function makeQuickNote(over: Partial<QuickNote> = {}): QuickNote {
  return {
    id: 'qn-1',
    date: DATE,
    content: '想到一个点子',
    sourceDevice: 'desktop',
    status: 'active',
    createdAt: '2026-06-23T09:30:00.000',
    updatedAt: '2026-06-23T09:30:00.000',
    ...over,
  };
}

describe('entity ↔ row 转换', () => {
  it('scheduleToRow / rowToSchedule：categoryColor 读出派生（不存库）', () => {
    const sch = makeSchedule({ category: '生活' });
    const row = scheduleToRow(sch);
    expect(row.category).toBe('生活');
    expect(row.type).toBe('task');
    expect(row.settled).toBe(false); // 当天写入恒未沉淀
    expect(row.deleted).toBe(false);
    // row 不含 categoryColor；rowToSchedule 读出时从 category 派生补回
    const restored = rowToSchedule(row);
    expect(restored.categoryColor).toBe(SCHEDULE_CATEGORY_COLORS['生活']);
    expect(restored.title).toBe('同步联调');
    expect(restored.startTime).toBe('09:00');
  });

  it('quickNoteToRow / rowToQuickNote：createdAt 完整保留，HH:mm 不存库', () => {
    const qn = makeQuickNote({ createdAt: '2026-06-23T14:05:00.000' });
    const row = quickNoteToRow(qn);
    expect(row.createdAt).toBe('2026-06-23T14:05:00.000'); // 完整 ISO 存库
    expect(row.deleted).toBe(false);
    const restored = rowToQuickNote(row);
    expect(restored.createdAt).toBe('2026-06-23T14:05:00.000');
    expect(restored.status).toBe('active');
  });

  it('reviewEntryToRow / rowToReviewEntry：以 questionId 为身份', () => {
    const r: ReviewEntry = { questionId: 'q-official-1', title: '今天完成了什么', content: '写完文档' };
    const row = reviewEntryToRow(r, DATE);
    expect(row.id).toBe('q-official-1'); // 复盘答案 id = questionId
    expect(row.questionId).toBe('q-official-1');
    expect(row.date).toBe(DATE);
    const restored = rowToReviewEntry(row);
    expect(restored.title).toBe('今天完成了什么');
    expect(restored.content).toBe('写完文档');
  });

  it('软删 quickNote（status=deleted）→ row.deleted=true', () => {
    const qn = makeQuickNote({ status: 'deleted' });
    const row = quickNoteToRow(qn);
    expect(row.deleted).toBe(true);
    const restored = rowToQuickNote(row);
    expect(restored.status).toBe('deleted');
  });
});

describe('内存兜底往返（非 Tauri）', () => {
  // 每个 it 前清内存，避免跨用例污染。
  beforeEach(() => {
    // 内存兜底是模块级 Map，无法直接清；用唯一 date 隔离各用例。
  });

  it('空数据 loadDailyEntities 返回空集合', async () => {
    const entities = await loadDailyEntities(ROOT, '2099-01-01');
    expect(entities.schedules).toHaveLength(0);
    expect(entities.quickNotes).toHaveLength(0);
    expect(entities.reviews).toHaveLength(0);
    expect(entities.focus).toBeNull();
  });

  it('batchReplaceSchedules → loadDailyEntities 往返等价（按 sortOrder 排序）', async () => {
    const uniq = '2099-02-02';
    const list = [
      makeSchedule({ id: 'a', date: uniq, sortOrder: 1, startTime: '10:00', title: '后' }),
      makeSchedule({ id: 'b', date: uniq, sortOrder: 0, startTime: '09:00', title: '前' }),
    ];
    await batchReplaceSchedules(ROOT, uniq, list);
    const loaded = await loadDailyEntities(ROOT, uniq);
    expect(loaded.schedules).toHaveLength(2);
    expect(loaded.schedules[0].id).toBe('b'); // sortOrder 0 在前
    expect(loaded.schedules[1].id).toBe('a');
    expect(loaded.schedules[0].categoryColor).toBe(SCHEDULE_CATEGORY_COLORS['工作']);
  });

  it('batchReplaceQuickNotes → load 按 createdAt 排序', async () => {
    const uniq = '2099-03-03';
    const list = [
      makeQuickNote({ id: 'x', date: uniq, createdAt: '2099-03-03T11:00:00.000', content: '午' }),
      makeQuickNote({ id: 'y', date: uniq, createdAt: '2099-03-03T08:00:00.000', content: '早' }),
    ];
    await batchReplaceQuickNotes(ROOT, uniq, list);
    const loaded = await loadDailyEntities(ROOT, uniq);
    expect(loaded.quickNotes).toHaveLength(2);
    expect(loaded.quickNotes[0].id).toBe('y'); // 早 8 点在前
    expect(loaded.quickNotes[0].createdAt).toBe('2099-03-03T08:00:00.000');
  });

  it('batchReplaceReviews → load 往返', async () => {
    const uniq = '2099-04-04';
    const list: ReviewEntry[] = [
      { questionId: 'q1', title: '完成了什么', content: 'A' },
      { questionId: 'q2', title: '收获', content: 'B' },
    ];
    await batchReplaceReviews(ROOT, uniq, list);
    const loaded = await loadDailyEntities(ROOT, uniq);
    expect(loaded.reviews).toHaveLength(2);
    expect(loaded.reviews.find((r) => r.questionId === 'q1')?.content).toBe('A');
  });

  it('upsertDailyFocus → load 取回 content', async () => {
    const uniq = '2099-05-05';
    await upsertDailyFocus(ROOT, uniq, '把今天最重要的两件事做完');
    const loaded = await loadDailyEntities(ROOT, uniq);
    expect(loaded.focus).toBe('把今天最重要的两件事做完');
  });

  it('再次 batchReplace 覆盖（旧实体被替换，不留残影）', async () => {
    const uniq = '2099-06-06';
    await batchReplaceSchedules(ROOT, uniq, [makeSchedule({ id: 'old', date: uniq })]);
    await batchReplaceSchedules(ROOT, uniq, [makeSchedule({ id: 'new', date: uniq })]);
    const loaded = await loadDailyEntities(ROOT, uniq);
    expect(loaded.schedules).toHaveLength(1);
    expect(loaded.schedules[0].id).toBe('new');
  });
});
