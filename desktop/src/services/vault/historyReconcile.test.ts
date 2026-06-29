import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { Schedule } from '../../shared/types/schedule';
import { SCHEDULE_CATEGORY_COLORS } from '../../shared/types/schedule';
import type { QuickNote } from '../../shared/types/quickNote';
import { batchReplaceSchedules } from './dailyEntities';
import {
  applyConflictResolution,
  buildContentDiff,
  importExternalMd,
  openHistoryDay,
  regenerateMdFromSql,
} from './historyReconcile';
import type { DailyDocModel, ReviewEntry } from './dailyDoc';

/**
 * historyReconcile 对账测试（非 Tauri 内存兜底）。
 *
 * vi.mock 提升问题用 vi.hoisted 解决：engine 的 onContentChange/readLocalFile、
 * existsVaultFile、sha256Hex 均需可控。内存兜底（dailyEntities）正常工作，
 * 构造各对账状态：settleDay 造 in_sync，手动改 memoryVault 模拟 conflict/external_only。
 */
const ROOT = '/test/vault';
const DATE = '2026-06-23';

const { onContentChangeMock, readLocalFileMock, existsVaultFileMock, sha256HexMock, diskVaultMock } = vi.hoisted(() => ({
  onContentChangeMock: vi.fn<(path: string, content: string) => Promise<void>>(),
  readLocalFileMock: vi.fn<(path: string) => Promise<string>>(),
  existsVaultFileMock: vi.fn<(root: string, path: string) => Promise<boolean>>(),
  sha256HexMock: vi.fn<(text: string) => Promise<string>>(),
  // 模拟磁盘 vault 内容（conflict/external_only 态用）
  diskVaultMock: new Map<string, string>(),
}));

vi.mock('.', () => ({
  getVaultEngineSingleton: () => ({
    onContentChange: onContentChangeMock,
    readLocalFile: readLocalFileMock,
  }),
}));

vi.mock('./vaultFileBridge', async (importOriginal: () => Promise<Record<string, unknown>>) => {
  const actual = await importOriginal();
  return {
    ...actual,
    existsVaultFile: existsVaultFileMock,
    sha256Hex: sha256HexMock,
  };
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

/** 内联 sha256（sha256Hex 被 mock，需要真实 hash 做沉淀对账场景时绕过 mock）。 */
async function realHash(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

describe('openHistoryDay 5 状态', () => {
  beforeEach(() => {
    onContentChangeMock.mockReset();
    onContentChangeMock.mockResolvedValue(undefined);
    readLocalFileMock.mockReset();
    existsVaultFileMock.mockReset();
    sha256HexMock.mockReset();
    diskVaultMock.clear();
    // 默认：existsVaultFile 读 diskVaultMock，readLocalFile 同
    existsVaultFileMock.mockImplementation(async (_root: string, path: string) => diskVaultMock.has(path));
    readLocalFileMock.mockImplementation(async (path: string) => diskVaultMock.get(path) ?? '');
    // sha256Hex 默认用真实实现（对账场景需真实 hash）
    sha256HexMock.mockImplementation(async (text: string) => realHash(text));
  });

  it('empty：无 settlement、无 .md、SQL 无数据', async () => {
    const result = await openHistoryDay(ROOT, '2099-01-01');
    expect(result.status).toBe('empty');
    expect(result.sqlEntities).toBeNull();
  });

  it('in_sync：settlement + .md hash 一致', async () => {
    await batchReplaceSchedules(ROOT, DATE, [makeSchedule()]);
    // settleDay 会调 onContentChange（被 mock），但我们要让磁盘 vault 也有内容 + 真实 hash
    // 直接用真实 sha256 计算，手动写入 diskVaultMock + settlement
    const { serializeCleanDailyDoc } = await import('./dailyDoc');
    const { upsertSettlement, settlementVaultPath, loadDailyEntities } = await import('./dailyEntities');
    const entities = await loadDailyEntities(ROOT, DATE);
    const model: DailyDocModel = {
      title: '2026年6月23日 周二',
      focus: entities.focus,
      schedules: entities.schedules,
      quickNotes: entities.quickNotes,
      review: entities.reviews,
    };
    const md = serializeCleanDailyDoc(model);
    const hash = await realHash(md);
    diskVaultMock.set(settlementVaultPath(DATE), md);
    await upsertSettlement(ROOT, { date: DATE, mdContentHash: hash, mdVaultPath: settlementVaultPath(DATE), settledAt: 't', settledBy: 'manual' });

    const result = await openHistoryDay(ROOT, DATE);
    expect(result.status).toBe('in_sync');
    expect(result.sqlEntities).not.toBeNull();
  });

  it('md_missing：有 settlement 但 .md 不存在', async () => {
    const { upsertSettlement, settlementVaultPath } = await import('./dailyEntities');
    await upsertSettlement(ROOT, {
      date: '2020-05-05',
      mdContentHash: 'abc',
      mdVaultPath: settlementVaultPath('2020-05-05'),
      settledAt: 't',
      settledBy: 'manual',
    });
    const result = await openHistoryDay(ROOT, '2020-05-05');
    expect(result.status).toBe('md_missing');
    expect(result.diskMd).toBeNull();
  });

  it('external_only：无 settlement 但有 .md', async () => {
    const { settlementVaultPath } = await import('./dailyEntities');
    diskVaultMock.set(settlementVaultPath('2020-06-06'), '# 外部文件\n');
    const result = await openHistoryDay(ROOT, '2020-06-06');
    expect(result.status).toBe('external_only');
    expect(result.diskMd).toBe('# 外部文件\n');
  });

  it('conflict：hash 不一致（.md 被外部改过）', async () => {
    const { upsertSettlement, settlementVaultPath } = await import('./dailyEntities');
    diskVaultMock.set(settlementVaultPath('2020-07-07'), '# 被改过的内容\n');
    await upsertSettlement(ROOT, {
      date: '2020-07-07',
      mdContentHash: '不同的hash值用于触发conflict',
      mdVaultPath: settlementVaultPath('2020-07-07'),
      settledAt: 't',
      settledBy: 'manual',
    });
    const result = await openHistoryDay(ROOT, '2020-07-07');
    expect(result.status).toBe('conflict');
    expect(result.diff).not.toBeNull();
  });
});

describe('buildContentDiff', () => {
  it('schedule 增删检测（指纹 startTime-endTime|title）', () => {
    const sql = {
      schedules: [makeSchedule({ id: 'a', startTime: '09:00', endTime: '10:00', title: 'A' })],
      quickNotes: [],
      reviews: [],
      focus: null,
    };
    const md: DailyDocModel = {
      title: '',
      focus: null,
      schedules: [
        { id: 'a', title: 'A', completed: false, category: '工作', categoryColor: '', type: 'task', startTime: '09:00', endTime: '10:00', date: DATE },
        { id: 'b', title: 'B', completed: false, category: '生活', categoryColor: '', type: 'task', startTime: '11:00', endTime: '12:00', date: DATE },
      ],
      quickNotes: [],
      review: [],
    };
    const diff = buildContentDiff(sql, md);
    const sched = diff.sections.find((s) => s.kind === '日程')!;
    expect(sched.addedInMd.some((s) => s.includes('B'))).toBe(true); // md 新增（指纹含 B 标题）
    expect(sched.removedFromMd).toHaveLength(0); // A 两边都有
    expect(diff.totalChanges).toBeGreaterThan(0);
  });

  it('quickNote 指纹 HH:mm|content', () => {
    const sql = {
      schedules: [],
      quickNotes: [makeQuickNote({ id: 'x', createdAt: '2026-06-23T08:00:00.000', content: '早' })],
      reviews: [],
      focus: null,
    };
    const md: DailyDocModel = {
      title: '',
      focus: null,
      schedules: [],
      quickNotes: [],
      review: [],
    };
    const diff = buildContentDiff(sql, md);
    const qn = diff.sections.find((s) => s.kind === '快速记录')!;
    expect(qn.removedFromMd.length).toBe(1); // md 删了
  });

  it('review title 匹配 + content changed', () => {
    const reviewA: ReviewEntry = { questionId: 'q1', title: '完成了什么', content: 'A' };
    const sql = { schedules: [], quickNotes: [], reviews: [reviewA], focus: null };
    const md: DailyDocModel = {
      title: '',
      focus: null,
      schedules: [],
      quickNotes: [],
      review: [
        { questionId: 'q1', title: '完成了什么', content: 'B' }, // content 改了
        { questionId: 'q2', title: '新题目', content: 'C' }, // md 新增
      ],
    };
    const diff = buildContentDiff(sql, md);
    const rv = diff.sections.find((s) => s.kind === '复盘')!;
    expect(rv.changed).toContain('完成了什么');
    expect(rv.addedInMd).toContain('新题目');
  });
});

describe('applyConflictResolution', () => {
  beforeEach(() => {
    onContentChangeMock.mockReset();
    onContentChangeMock.mockResolvedValue(undefined);
    sha256HexMock.mockReset();
    sha256HexMock.mockResolvedValue('resolved-hash');
  });

  it('keep_sql：以 SQL 为准重生成 .md + 更新 settlement', async () => {
    await batchReplaceSchedules(ROOT, '2018-01-01', [makeSchedule({ id: 's', date: '2018-01-01', title: '旧记录' })]);
    await applyConflictResolution(ROOT, '2018-01-01', 'keep_sql');

    expect(onContentChangeMock).toHaveBeenCalledTimes(1);
    const [path, content] = onContentChangeMock.mock.calls[0];
    expect(path).toBe('Notes/Daily/2018-01-01.md');
    expect(content).toContain('旧记录');
    expect(content).not.toContain('<!--');

    const { getSettlement } = await import('./dailyEntities');
    const settlement = await getSettlement(ROOT, '2018-01-01');
    expect(settlement!.mdContentHash).toBe('resolved-hash');
  });

  it('keep_md：以 .md 为准回写 SQL（parseCleanMd → batchReplace）', async () => {
    const { settlementVaultPath } = await import('./dailyEntities');
    const mdContent = `# 2018年2月2日\n\n## 今日日程\n- [ ] 10:00-11:00 来自文件（工作）\n`;
    diskVaultMock.set(settlementVaultPath('2018-02-02'), mdContent);
    readLocalFileMock.mockResolvedValue(mdContent);

    await applyConflictResolution(ROOT, '2018-02-02', 'keep_md');

    const { loadDailyEntities } = await import('./dailyEntities');
    const entities = await loadDailyEntities(ROOT, '2018-02-02');
    expect(entities.schedules).toHaveLength(1);
    expect(entities.schedules[0].title).toBe('来自文件');
  });

  it('regenerateMdFromSql / importExternalMd 是 keep_sql / keep_md 的别名', async () => {
    await batchReplaceSchedules(ROOT, '2017-03-03', [makeSchedule({ id: 'r', date: '2017-03-03' })]);
    onContentChangeMock.mockClear();
    await regenerateMdFromSql(ROOT, '2017-03-03');
    expect(onContentChangeMock).toHaveBeenCalledTimes(1); // 同 keep_sql

    const { settlementVaultPath } = await import('./dailyEntities');
    diskVaultMock.set(settlementVaultPath('2017-04-04'), '# 导入\n');
    readLocalFileMock.mockResolvedValue('# 导入\n');
    await importExternalMd(ROOT, '2017-04-04'); // 同 keep_md，不报错即可
    expect(true).toBe(true);
  });
});
