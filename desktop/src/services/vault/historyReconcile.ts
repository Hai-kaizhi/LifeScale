/**
 * 历史回看对账（docs/09 第八章）。
 *
 * 用户打开历史日期时判定 5 种状态（empty/in_sync/md_missing/external_only/conflict），
 * conflict 时做 SQL 归档 ↔ 磁盘 .md 的内容指纹比对 + 整单拍板写回。
 *
 * 详情数据源统一为 SQL 归档实体（loadDailyEntities，settled=1 实体仍在主表），
 * .md 仅用于对账判定（hash 比对）与拍板写回——不依赖 .md 是否存在/被改，
 * 保证用户打开历史永远看得到结构化数据。
 */
import dayjs from 'dayjs';
import { getVaultEngineSingleton } from '.';
import { parseCleanMd, serializeCleanDailyDoc, type DailyDocModel, type ReviewEntry } from './dailyDoc';
import {
  batchReplaceQuickNotes,
  batchReplaceReviews,
  batchReplaceSchedules,
  getSettlement,
  loadDailyEntities,
  settlementVaultPath,
  upsertDailyFocus,
  upsertSettlement,
  type DailyEntitiesData,
} from './dailyEntities';
import { getWeekday } from '../../shared/utils/date';
import { existsVaultFile, sha256Hex } from './vaultFileBridge';

/** 历史日期的 5 种对账状态（docs/09 §8.2）。 */
export type HistoryDayStatus = 'empty' | 'in_sync' | 'md_missing' | 'external_only' | 'conflict';

/** 内容指纹 diff 单项（一类实体的增删改摘要）。 */
export interface DiffSection {
  /** '日程' | '快速记录' | '复盘' */
  kind: string;
  /** 仅在 .md 中存在（SQL 侧删除了，或外部新增）。 */
  addedInMd: string[];
  /** 仅在 SQL 中存在（.md 侧删除了，即用户在 Obsidian 删行）。 */
  removedFromMd: string[];
  /** 两边都有但内容不一致。 */
  changed: string[];
}

export interface ContentDiff {
  sections: DiffSection[];
  /** 变更总条数（用于 UI 摘要）。 */
  totalChanges: number;
}

export interface HistoryDayResult {
  status: HistoryDayStatus;
  date: string;
  /** SQL 归档实体（所有非 empty 态都填，详情数据源）。 */
  sqlEntities: DailyEntitiesData | null;
  /** 磁盘 .md 原文（md_missing 之外的态，若文件存在则填）。 */
  diskMd: string | null;
  /** 沉淀记录（settled 态填）。 */
  settlementHash: string | null;
  /** 字段级 diff（仅 conflict 态填）。 */
  diff: ContentDiff | null;
}

/** 冲突解决策略（docs/09 §8.3 整单拍板）。 */
export type ConflictResolution = 'keep_sql' | 'keep_md';

function nowIso(): string {
  return new Date().toISOString();
}

/** 日期标题（与 settlementService.buildTitle 同口径，保证重生成 .md 与沉淀时一致）。 */
function buildTitle(date: string): string {
  return `${dayjs(date).format('YYYY年M月D日')} ${getWeekday(date).replace('星期', '周')}`;
}

/**
 * 判定历史日期的对账状态 + 取详情数据（docs/09 §8.1）。
 *
 * 判定逻辑：
 * - empty：当天从未有数据（无 settlement 无 .md）
 * - md_missing：沉淀过但 .md 被删 → 用 SQL 重生成
 * - in_sync：沉淀记录的 hash 与磁盘 .md 当前 hash 一致
 * - conflict：hash 不一致（.md 被外部/Obsidian 改过）
 * - external_only：无沉淀记录但有 .md（用户手放/外部新建）
 *
 * 详情恒从 SQL 归档（loadDailyEntities）读取，保证结构化数据可见。
 */
export async function openHistoryDay(root: string, date: string): Promise<HistoryDayResult> {
  const settlement = await getSettlement(root, date);
  const mdPath = settlementVaultPath(date);
  const mdExists = await existsVaultFile(root, mdPath);

  // 磁盘 .md 原文与 SQL 详情并行读取
  const diskMd = mdExists ? await getVaultEngineSingleton().readLocalFile(mdPath) : '';
  const sqlEntities = await loadDailyEntities(root, date);

  const isEmptySql =
    sqlEntities.schedules.length === 0 &&
    sqlEntities.quickNotes.length === 0 &&
    sqlEntities.reviews.length === 0 &&
    sqlEntities.focus === null;

  // empty：无沉淀记录、无 .md、且 SQL 也无数据
  if (!settlement && !mdExists && isEmptySql) {
    return { status: 'empty', date, sqlEntities: null, diskMd: null, settlementHash: null, diff: null };
  }

  // external_only：无沉淀记录但有 .md（外部新建）；SQL 详情仍读（可能空）
  if (!settlement && mdExists) {
    return {
      status: 'external_only',
      date,
      sqlEntities,
      diskMd,
      settlementHash: null,
      diff: null,
    };
  }

  // md_missing：有沉淀记录但 .md 不存在
  if (settlement && !mdExists) {
    return {
      status: 'md_missing',
      date,
      sqlEntities,
      diskMd: null,
      settlementHash: settlement.mdContentHash,
      diff: null,
    };
  }

  // 兜底：无沉淀记录时无法做 hash 对账，统一归为 external_only（避免对 null settlement 访问属性）。
  // 覆盖"无沉淀但有 .md 且 SQL 非空"等边界组合——详情仍从 SQL 读取，不丢数据。
  if (!settlement) {
    return {
      status: 'external_only',
      date,
      sqlEntities,
      diskMd: mdExists ? diskMd : null,
      settlementHash: null,
      diff: null,
    };
  }

  // 此后 settlement 与 mdExists 都为 true：比对 hash
  const diskHash = await sha256Hex(diskMd);
  if (diskHash === settlement.mdContentHash) {
    return { status: 'in_sync', date, sqlEntities, diskMd, settlementHash: settlement.mdContentHash, diff: null };
  }

  // conflict：hash 不一致，生成字段级 diff
  const mdModel = parseCleanMd(diskMd, { date }).model;
  const diff = buildContentDiff(sqlEntities, mdModel);
  return { status: 'conflict', date, sqlEntities, diskMd, settlementHash: settlement.mdContentHash, diff };
}

/**
 * 内容指纹 diff（docs/09 §8.3）。沉淀 .md 不带 ID，匹配只能靠内容指纹。
 * - schedule：startTime+endTime+title 三元组
 * - quickNote：HH:mm+content（从 createdAt 派生 HH:mm）
 * - review：title（.md 无 questionId，按 title 匹配）+ content
 */
export function buildContentDiff(sql: DailyEntitiesData, md: DailyDocModel): ContentDiff {
  const sections: DiffSection[] = [];

  // ---- schedule（指纹 startTime-endTime|title）----
  const sqlSched = sql.schedules.map((s) => `${s.startTime}-${s.endTime} ${s.title}`);
  const mdSched = md.schedules.map((s) => `${s.startTime}-${s.endTime} ${s.title}`);
  sections.push(diffArrays('日程', sqlSched, mdSched));

  // ---- quickNote（指纹 HH:mm|content）----
  const sqlQn = sql.quickNotes.map((q) => `${qnTime(q.createdAt)} ${q.content}`);
  const mdQn = md.quickNotes.map((q) => `${qnTime(q.createdAt)} ${q.content}`);
  sections.push(diffArrays('快速记录', sqlQn, mdQn));

  // ---- review（title 作指纹；changed 比较 content）----
  const sqlReviewTitles = new Map(sql.reviews.map((r) => [r.title, r]));
  const mdReviewTitles = new Map(md.review.map((r) => [r.title, r]));
  const addedInMd: string[] = [];
  const removedFromMd: string[] = [];
  const changed: string[] = [];
  for (const [title, mdR] of mdReviewTitles) {
    const sqlR = sqlReviewTitles.get(title);
    if (!sqlR) {
      addedInMd.push(title);
    } else if (sqlR.content !== mdR.content) {
      changed.push(title);
    }
  }
  for (const [title] of sqlReviewTitles) {
    if (!mdReviewTitles.has(title)) removedFromMd.push(title);
  }
  sections.push({ kind: '复盘', addedInMd, removedFromMd, changed });

  const totalChanges = sections.reduce((sum, s) => sum + s.addedInMd.length + s.removedFromMd.length + s.changed.length, 0);
  return { sections, totalChanges };
}

/** 通用集合 diff（按指纹字符串匹配；changed 暂归入 addedInMd/removedFromMd，实体级 changed 在 review 单独处理）。 */
function diffArrays(kind: string, sqlFingerprints: string[], mdFingerprints: string[]): DiffSection {
  const sqlSet = new Set(sqlFingerprints);
  const mdSet = new Set(mdFingerprints);
  const addedInMd: string[] = [];
  const removedFromMd: string[] = [];
  for (const fp of mdFingerprints) {
    if (!sqlSet.has(fp)) addedInMd.push(fp);
  }
  for (const fp of sqlFingerprints) {
    if (!mdSet.has(fp)) removedFromMd.push(fp);
  }
  return { kind, addedInMd, removedFromMd, changed: [] };
}

/** 从 createdAt ISO 取 HH:mm（与 dailyDoc.quickNoteTime 同口径）。 */
function qnTime(createdAt: string): string {
  const m = createdAt.match(/T(\d{2}:\d{2})/);
  return m ? m[1] : '00:00';
}

/**
 * 应用冲突解决（docs/09 §8.3 整单拍板写回）。
 *
 * - keep_sql：以 SQL 归档为准 → serializeCleanDailyDoc → 写 .md → 重算 hash → upsertSettlement
 * - keep_md：以 .md 为准 → parseCleanMd → batchReplace* 覆盖 SQL → upsertSettlement
 *
 * 两种策略都消除冲突（更新 settlement hash 至新一致态）。
 */
export async function applyConflictResolution(
  root: string,
  date: string,
  resolution: ConflictResolution,
): Promise<void> {
  const mdPath = settlementVaultPath(date);
  const engine = getVaultEngineSingleton();

  if (resolution === 'keep_sql') {
    const entities = await loadDailyEntities(root, date);
    const model: DailyDocModel = {
      title: buildTitle(date), // 与沉淀时同口径，保证 hash 可对账
      focus: entities.focus,
      schedules: entities.schedules,
      quickNotes: entities.quickNotes,
      review: entities.reviews,
    };
    const md = serializeCleanDailyDoc(model);
    await engine.onContentChange(mdPath, md); // 写 .md + 同步链路
    const hash = await sha256Hex(md);
    await upsertSettlement(root, {
      date,
      mdContentHash: hash,
      mdVaultPath: mdPath,
      settledAt: nowIso(),
      settledBy: 'manual',
    });
    return;
  }

  // keep_md：以磁盘 .md 为准回写 SQL
  const diskMd = await engine.readLocalFile(mdPath);
  const mdModel = parseCleanMd(diskMd, { date }).model;
  await Promise.all([
    batchReplaceSchedules(root, date, mdModel.schedules),
    batchReplaceQuickNotes(root, date, mdModel.quickNotes),
    batchReplaceReviews(root, date, mdModel.review),
    upsertDailyFocus(root, date, mdModel.focus),
  ]);
  // hash 应与磁盘一致（重新算磁盘 .md 的 hash 存入）
  const hash = await sha256Hex(diskMd);
  await upsertSettlement(root, {
    date,
    mdContentHash: hash,
    mdVaultPath: mdPath,
    settledAt: nowIso(),
    settledBy: 'manual',
  });
}

/**
 * 导入外部 .md 到 SQL（external_only 态）。逻辑同 keep_md。
 */
export async function importExternalMd(root: string, date: string): Promise<void> {
  await applyConflictResolution(root, date, 'keep_md');
}

/**
 * md_missing 态：从 SQL 归档重新生成 .md（逻辑同 keep_sql）。
 */
export async function regenerateMdFromSql(root: string, date: string): Promise<void> {
  await applyConflictResolution(root, date, 'keep_sql');
}

/** 复盘答案内容指纹辅助（导出供 UI 复用）。 */
export type { ReviewEntry };
