/**
 * Daily 沉淀服务（docs/09 第七章）。
 *
 * 沉淀 = 把当天 SQLite 结构化实体（日程/快速记录/复盘/今日重点）一次性归档为
 * 零注释的干净 .md（docs/09 §12.1），写入 `Notes/Daily/<date>.md`，算 SHA-256 存
 * `ls_daily_settlement` 供 P3 回看对账，并标记当天实体 settled=1。
 *
 * 这是 WAL+Checkpoint 模式的「Checkpoint」动作：沉淀那一刻 SQL 与 .md 天然一致，
 * 之后 .md 独立演进（用户可在 Obsidian 自由编辑），回看时按需对账（P3）。
 */
import dayjs from 'dayjs';
import { getVaultEngineSingleton } from '.';
import { serializeCleanDailyDoc, type DailyDocModel } from './dailyDoc';
import {
  getSettlement,
  listUnsettledPastDates,
  loadDailyEntities,
  markDailyEntitiesSettled,
  settlementVaultPath,
  upsertSettlement,
} from './dailyEntities';
import { getWeekday } from '../../shared/utils/date';
import { sha256Hex } from './vaultFileBridge';

export type SettleTrigger = 'manual' | 'lazy-backfill';

export interface SettlementEmptyResult {
  status: 'empty';
  date: string;
}

export interface SettlementDoneResult {
  status: 'settled';
  date: string;
  mdVaultPath: string;
  mdContentHash: string;
  /** 是否为覆盖式沉淀（当天已有沉淀记录，本次重新生成覆盖）。 */
  overwritten: boolean;
}

export type SettlementResult = SettlementEmptyResult | SettlementDoneResult;

export interface LazyBackfillResult {
  /** 本次实际沉淀的日期（升序）。 */
  settledDates: string[];
  /** 跳过的空数据日期（有未沉淀记录但实体为空，理论上罕见）。 */
  skipped: number;
}

function buildTitle(date: string): string {
  return `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`;
}

function nowIso(): string {
  return new Date().toISOString();
}

/**
 * 判定当天实体是否为空（无任何 schedule/quickNote/review/focus）。
 */
function isEmptyEntities(entities: {
  schedules: unknown[];
  quickNotes: unknown[];
  reviews: unknown[];
  focus: string | null;
}): boolean {
  return (
    entities.schedules.length === 0 &&
    entities.quickNotes.length === 0 &&
    entities.reviews.length === 0 &&
    entities.focus === null
  );
}

/**
 * 沉淀某天（docs/09 §7.2 算法）。
 *
 * 流程：
 * 1. 读当天实体（settled 实体仍可读 → 支持覆盖式沉淀）
 * 2. 空数据 → 返回 empty，不写 .md
 * 3. serializeCleanDailyDoc → 干净 .md
 * 4. sha256Hex 算 hash
 * 5. engine.onContentChange 写 Notes/Daily/<date>.md（复用写文件+同步链路）
 * 6. markDailyEntitiesSettled 标 4 表 settled=1
 * 7. upsertSettlement 存对账记录
 *
 * 幂等：同一天多次沉淀 → 重新生成 .md 覆盖 + 更新 settlement（docs/09 §7.4）。
 */
export async function settleDay(
  root: string,
  date: string,
  opts?: { settledBy?: SettleTrigger },
): Promise<SettlementResult> {
  const entities = await loadDailyEntities(root, date);
  if (isEmptyEntities(entities)) {
    return { status: 'empty', date };
  }

  const model: DailyDocModel = {
    title: buildTitle(date),
    focus: entities.focus,
    schedules: entities.schedules,
    quickNotes: entities.quickNotes,
    review: entities.reviews,
  };
  const cleanMd = serializeCleanDailyDoc(model);
  const mdVaultPath = settlementVaultPath(date);
  const mdContentHash = await sha256Hex(cleanMd);

  const engine = getVaultEngineSingleton();
  await engine.onContentChange(mdVaultPath, cleanMd); // 原子写本地 + upsert dirty + 入队推送

  await markDailyEntitiesSettled(root, date);

  const prev = await getSettlement(root, date);
  await upsertSettlement(root, {
    date,
    mdContentHash,
    mdVaultPath,
    settledAt: nowIso(),
    settledBy: opts?.settledBy ?? 'manual',
  });

  return { status: 'settled', date, mdVaultPath, mdContentHash, overwritten: prev !== null };
}

/**
 * 惰性补沉淀（docs/09 §7.3）：打开应用时扫描「过去日期且未沉淀」的记录，按日期升序逐个沉淀。
 *
 * 不依赖定时器（手机被杀后台后定时器失效）；打开应用时执行是可靠兜底。
 * 单个日期沉淀失败不影响其他日期（catch 隔离）。
 */
export async function lazyBackfillOnAppOpen(root: string): Promise<LazyBackfillResult> {
  const today = dayjs().format('YYYY-MM-DD');
  const dates = await listUnsettledPastDates(root, today);
  const settledDates: string[] = [];
  let skipped = 0;

  for (const date of dates) {
    try {
      const result = await settleDay(root, date, { settledBy: 'lazy-backfill' });
      if (result.status === 'settled') {
        settledDates.push(date);
      } else {
        skipped += 1;
      }
    } catch {
      // 单日失败隔离，继续处理其他日期
      skipped += 1;
    }
  }

  return { settledDates, skipped };
}
