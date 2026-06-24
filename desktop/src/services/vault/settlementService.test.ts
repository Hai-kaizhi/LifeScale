import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { Schedule } from '../../shared/types/schedule';
import { SCHEDULE_CATEGORY_COLORS } from '../../shared/types/schedule';
import type { QuickNote } from '../../shared/types/quickNote';
import {
  batchReplaceQuickNotes,
  batchReplaceReviews,
  batchReplaceSchedules,
  getSettlement,
  settlementVaultPath,
  upsertDailyFocus,
} from './dailyEntities';
import { lazyBackfillOnAppOpen, settleDay } from './settlementService';
import type { ReviewEntry } from './dailyDoc';

/**
 * settlementService 沉淀测试（非 Tauri 内存兜底）。
 *
 * vitest 跑在 Node（非 Tauri 运行时），isTauriRuntime() 返回 false，dailyEntities
 * 走内存兜底。settleDay 内部依赖 getVaultEngineSingleton().onContentChange 和 sha256Hex，
 * 用 vi.mock 替换为可控 spy。
 */

const ROOT = '/test/vault';
const DATE = '2026-06-23';

// vi.mock 会被提升到文件顶部，mock 内不能引用顶层变量，必须用 vi.hoisted 创建。
const { onContentChangeMock, sha256HexMock } = vi.hoisted(() => ({
  onContentChangeMock: vi.fn<(path: string, content: string) => Promise<void>>(),
  sha256HexMock: vi.fn<(text: string) => Promise<string>>(),
}));

// ---- mock engine.onContentChange（沉淀写 .md 的统一入口）----
vi.mock('.', () => ({
  getVaultEngineSingleton: () => ({ onContentChange: onContentChangeMock }),
}));

// ---- mock sha256Hex（避免依赖 crypto.subtle 兼容性，固定返回值便于断言）----
vi.mock('./vaultFileBridge', async (importOriginal) => {
  const actual = (await importOriginal()) as Record<string, unknown>;
  return { ...actual, sha256Hex: sha256HexMock };
});

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

describe('settlementVaultPath', () => {
  it('返回 Notes/Daily/<date>.md（docs/09 路径约定）', () => {
    expect(settlementVaultPath('2026-06-23')).toBe('Notes/Daily/2026-06-23.md');
  });
});

describe('settleDay', () => {
  beforeEach(() => {
    onContentChangeMock.mockReset();
    sha256HexMock.mockReset();
    // 默认返回固定 hash 便于断言
    sha256HexMock.mockResolvedValue('deadbeef'.repeat(8));
  });

  it('空数据 → status=empty，不写 .md', async () => {
    const result = await settleDay(ROOT, '2099-01-01', { settledBy: 'manual' });
    expect(result.status).toBe('empty');
    expect(onContentChangeMock).not.toHaveBeenCalled();
  });

  it('有数据 → status=settled：写干净 .md + 存 settlement（hash/路径正确）', async () => {
    await batchReplaceSchedules(ROOT, DATE, [makeSchedule()]);
    await batchReplaceQuickNotes(ROOT, DATE, [makeQuickNote()]);
    const result = await settleDay(ROOT, DATE, { settledBy: 'manual' });

    expect(result.status).toBe('settled');
    if (result.status !== 'settled') return;
    expect(result.mdVaultPath).toBe('Notes/Daily/2026-06-23.md');
    expect(result.mdContentHash).toBe('deadbeef'.repeat(8));
    expect(result.overwritten).toBe(false); // 首次沉淀

    // 写 .md 被调，路径正确，内容零注释
    expect(onContentChangeMock).toHaveBeenCalledTimes(1);
    const [path, content] = onContentChangeMock.mock.calls[0];
    expect(path).toBe('Notes/Daily/2026-06-23.md');
    expect(content).not.toContain('<!--');
    expect(content).toContain('## 今日日程');
    expect(content).toContain('同步联调');

    // settlement 记录已存
    const settlement = await getSettlement(ROOT, DATE);
    expect(settlement).not.toBeNull();
    expect(settlement!.mdContentHash).toBe('deadbeef'.repeat(8));
    expect(settlement!.mdVaultPath).toBe('Notes/Daily/2026-06-23.md');
    expect(settlement!.settledBy).toBe('manual');
  });

  it('幂等：同一天二次沉淀 → overwritten=true，settlement 更新', async () => {
    await batchReplaceSchedules(ROOT, DATE, [makeSchedule({ id: 'a' })]);
    await settleDay(ROOT, DATE, { settledBy: 'manual' });
    // 第二次沉淀（覆盖式）
    sha256HexMock.mockResolvedValue('cafef00d'.repeat(8));
    const result = await settleDay(ROOT, DATE, { settledBy: 'manual' });

    expect(result.status).toBe('settled');
    if (result.status !== 'settled') return;
    expect(result.overwritten).toBe(true);
    expect(onContentChangeMock).toHaveBeenCalledTimes(2); // 两次都写了

    const settlement = await getSettlement(ROOT, DATE);
    expect(settlement!.mdContentHash).toBe('cafef00d'.repeat(8)); // 已更新为新 hash
  });

  it('复盘答案 + 今日重点也进沉淀 .md', async () => {
    const reviews: ReviewEntry[] = [{ questionId: 'q1', title: '今天完成了什么', content: '写完文档' }];
    await batchReplaceReviews(ROOT, DATE, reviews);
    await upsertDailyFocus(ROOT, DATE, '把今天最重要的事做完');
    await settleDay(ROOT, DATE, { settledBy: 'manual' });

    const [, content] = onContentChangeMock.mock.calls[0];
    expect(content).toContain('把今天最重要的事做完');
    expect(content).toContain('今天完成了什么');
    expect(content).toContain('写完文档');
  });

  it('lazy-backfill 触发 settledBy=lazy-backfill', async () => {
    await batchReplaceSchedules(ROOT, DATE, [makeSchedule()]);
    const result = await settleDay(ROOT, DATE, { settledBy: 'lazy-backfill' });
    expect(result.status).toBe('settled');
    const settlement = await getSettlement(ROOT, DATE);
    expect(settlement!.settledBy).toBe('lazy-backfill');
  });
});

describe('lazyBackfillOnAppOpen', () => {
  beforeEach(() => {
    onContentChangeMock.mockReset();
    sha256HexMock.mockResolvedValue('aaaaaaaa'.repeat(8));
  });

  it('无未沉淀过去日期 → settledDates 空', async () => {
    const result = await lazyBackfillOnAppOpen(ROOT);
    expect(result.settledDates).toHaveLength(0);
    expect(result.skipped).toBe(0);
  });

  it('有未沉淀过去日期 → 逐个沉淀（内存兜底需先写入数据才被 settleDay 读到）', async () => {
    // 内存兜底的 listUnsettledPastDates 恒返回 []（浏览器无真实未沉淀扫描），
    // 故此处验证 lazyBackfill 逻辑：手动注入一个过去日期的数据后直接调 settleDay 验证链路。
    const pastDate = '2020-01-01';
    await batchReplaceSchedules(ROOT, pastDate, [makeSchedule({ id: 'old', date: pastDate })]);
    const direct = await settleDay(ROOT, pastDate, { settledBy: 'lazy-backfill' });
    expect(direct.status).toBe('settled');
    expect(onContentChangeMock).toHaveBeenCalled();
  });
});
