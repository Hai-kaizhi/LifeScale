/**
 * 结构化 Daily Markdown 解析器 / 序列化器（文法契约见 docs/06 第 3 节）。
 *
 * 行尾 HTML 注释嵌入稳定 ID，保证可往返：
 * - 自由文本重点：`- 文本 <!-- focus -->`
 * - 重点日程引用：`- HH:MM-HH:MM 标题 <!-- sid:<id> -->`（实体在「今日日程」段）
 * - 任务日程：`- [x| ] HH:MM-HH:MM 标题（类别） <!-- sid:<id> -->`
 * - 记录类日程（时间记录子段）：`- HH:MM-HH:MM 标题（记录） <!-- sid:<id> -->`
 * - 快速记录：`- HH:mm 内容 <!-- qn:<id> -->`
 * - 复盘题目：`### 标题 <!-- rv:<questionId> -->` + 其后缩进正文
 *
 * 老文件（无 ID）→ parse 时自动补 ID 并标记 dirty 以便写回。
 * 空段占位（「暂无…。」）不带注释。
 */
import type { Schedule, ScheduleCategory, ScheduleType } from '../../shared/types/schedule';
import { SCHEDULE_CATEGORY_COLORS } from '../../shared/types/schedule';
import type { QuickNote } from '../../shared/types/quickNote';

/** 复盘单条答案（题目 + 正文）—— dailyDoc 本地模型用，区别于 shared 的 DailyReviewAnswer（无 title）。 */
export interface ReviewEntry {
  questionId: string;
  title: string;
  content: string;
}

/** 解析后的每日文档结构化模型。 */
export interface DailyDocModel {
  title: string;
  /** 自由文本重点（DateEntity.focus，单条）。 */
  focus: string | null;
  schedules: Schedule[];
  quickNotes: QuickNote[];
  review: ReviewEntry[];
}

export interface ParseResult {
  model: DailyDocModel;
  /** 老文件缺 ID，已补 ID，需写回。 */
  dirty: boolean;
}

type Section = 'none' | 'focus' | 'schedule' | 'note' | 'quicknote' | 'review';

const COMMENT_RE = /\s*<!--\s*([a-zA-Z]+)(?::([0-9A-Za-z_-]+))?\s*-->\s*$/;
const TASK_HEAD_RE = /^- \[([xX ])\] (.+)$/;
const BULLET_RE = /^- (.+)$/;
const RANGE_RE = /^(\d{1,2}:\d{2})-(\d{1,2}:\d{2}) (.+)（([^）]+)）$/;
const QUICK_RE = /^(\d{1,2}:\d{2}) (.+)$/;
const TIME_IN_ISO_RE = /T(\d{2}:\d{2})/;

function newId(): string {
  try {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID();
    }
  } catch {
    /* fallthrough */
  }
  return `id-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

/** 拆分行尾 HTML 注释，返回正文与 { key, id }。 */
function parseComment(line: string): { body: string; key: string | null; id: string | null } {
  const m = line.match(COMMENT_RE);
  if (!m) return { body: line, key: null, id: null };
  const body = line.slice(0, m.index).trimEnd();
  return { body, key: m[1].toLowerCase(), id: m[2] ?? null };
}

function indentMultiline(value: string): string {
  return value
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => `  ${line}`)
    .join('\n');
}

/** 从 createdAt（ISO 或 YYYY-MM-DDTHH:mm:...）取 HH:mm。 */
function quickNoteTime(createdAt: string): string {
  const m = createdAt.match(TIME_IN_ISO_RE);
  return m ? m[1] : '00:00';
}

function normalizeCategory(raw: string): ScheduleCategory {
  return raw === '工作' ? '工作' : '生活';
}

function parseScheduleLine(
  line: string,
  type: ScheduleType,
  date: string,
  order: number,
  assignId: () => string,
): Schedule | null {
  const { body, key, id } = parseComment(line);
  let rest: string | null = null;
  let mark: string | null = null;
  if (type === 'task') {
    const tm = body.match(TASK_HEAD_RE);
    if (!tm) return null;
    mark = tm[1];
    rest = tm[2];
  } else {
    const nm = body.match(BULLET_RE);
    if (!nm) return null;
    rest = nm[1];
  }
  const rm = rest.match(RANGE_RE);
  if (!rm) return null;
  const [, start, end, title, categoryRaw] = rm;
  const sid = key === 'sid' && id ? id : assignId();
  const category = type === 'note' ? normalizeCategory(categoryRaw) : normalizeCategory(categoryRaw);
  return {
    id: sid,
    title: title.trim(),
    completed: type === 'task' ? mark !== null && mark.toLowerCase() === 'x' : false,
    category,
    categoryColor: SCHEDULE_CATEGORY_COLORS[category],
    type,
    startTime: start,
    endTime: end,
    date,
    sortOrder: order,
  };
}

function parseQuickNoteLine(
  line: string,
  date: string,
  assignId: () => string,
): QuickNote | null {
  const { body, key, id } = parseComment(line);
  const m = body.match(BULLET_RE);
  if (!m) return null;
  const qm = m[1].match(QUICK_RE);
  if (!qm) return null;
  const [, time, content] = qm;
  const qnId = key === 'qn' && id ? id : assignId();
  const createdAt = `${date}T${time}:00.000`;
  return {
    id: qnId,
    date,
    content: content.trim(),
    sourceDevice: 'desktop',
    status: 'active',
    createdAt,
    updatedAt: createdAt,
  };
}

/** 解析 Daily Markdown。date 用于补全 schedule.date 与 quickNote.createdAt。 */
export function parseDailyDoc(md: string, opts?: { date?: string }): ParseResult {
  const date = opts?.date ?? '';
  const lines = md.split(/\r?\n/);

  let title = '';
  let focus: string | null = null;
  const schedules: Schedule[] = [];
  const quickNotes: QuickNote[] = [];
  const review: ReviewEntry[] = [];
  const focusScheduleIds: string[] = [];

  let section: Section = 'none';
  let currentReview: ReviewEntry | null = null;
  let dirty = false;
  let order = 0;

  const assignId = (): string => {
    dirty = true;
    return newId();
  };

  for (const rawLine of lines) {
    const trimmed = rawLine.trim();
    if (trimmed === '') continue;

    if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
      title = trimmed.slice(2).trim();
      continue;
    }
    if (trimmed === '## 今日重点') {
      section = 'focus';
      continue;
    }
    if (trimmed === '## 今日日程') {
      section = 'schedule';
      continue;
    }
    if (trimmed === '## 快速记录') {
      section = 'quicknote';
      continue;
    }
    if (trimmed === '## 今日复盘') {
      if (currentReview) review.push(currentReview);
      currentReview = null;
      section = 'review';
      continue;
    }
    if (trimmed === '### 时间记录' && section === 'schedule') {
      section = 'note';
      continue;
    }
    if (trimmed.startsWith('### ') && section === 'review') {
      if (currentReview) review.push(currentReview);
      const { body, key, id } = parseComment(trimmed);
      const reviewTitle = body.replace(/^###\s+/, '').trim();
      let questionId: string;
      if (key === 'rv' && id) {
        questionId = id;
      } else {
        questionId = id ?? assignId();
        dirty = true;
      }
      currentReview = { questionId, title: reviewTitle, content: '' };
      continue;
    }

    switch (section) {
      case 'focus': {
        if (!/^- /.test(trimmed)) continue; // 占位行（暂无…。）忽略
        const { body, key, id } = parseComment(trimmed);
        const text = body.replace(/^-\s+/, '').trim();
        if (key === 'focus') {
          focus = text;
        } else if (key === 'sid' && id) {
          focusScheduleIds.push(id);
        } else if (focus === null && text) {
          // 无注释旧行：兼容当自由重点
          focus = text;
        }
        continue;
      }
      case 'schedule': {
        const sch = parseScheduleLine(trimmed, 'task', date, order, assignId);
        if (sch) {
          schedules.push(sch);
          order += 1;
        }
        continue;
      }
      case 'note': {
        const sch = parseScheduleLine(trimmed, 'note', date, order, assignId);
        if (sch) {
          schedules.push(sch);
          order += 1;
        }
        continue;
      }
      case 'quicknote': {
        const qn = parseQuickNoteLine(trimmed, date, assignId);
        if (qn) quickNotes.push(qn);
        continue;
      }
      case 'review': {
        // 缩进行 → 当前问题答案（容错：任意前导空白，非仅 2 空格）
        if (currentReview && /^\s+\S/.test(rawLine)) {
          const lineText = rawLine.trim();
          if (lineText && lineText !== '暂无。') {
            currentReview.content = currentReview.content
              ? `${currentReview.content}\n${lineText}`
              : lineText;
          }
        }
        // 非缩进非标题行（如占位「暂无。」）→ 忽略
        continue;
      }
      default:
        continue;
    }
  }
  if (currentReview) review.push(currentReview);

  // 应用重点引用 → schedule.focus
  const focusSet = new Set(focusScheduleIds);
  if (focusSet.size) {
    for (const s of schedules) {
      if (focusSet.has(s.id)) s.focus = true;
    }
  }

  return {
    model: { title, focus, schedules, quickNotes, review },
    dirty,
  };
}

/** 序列化 Daily Markdown（带 ID、段间空行，Obsidian 友好）。 */
export function serializeDailyDoc(model: DailyDocModel): string {
  const parts: string[] = [];

  parts.push(`# ${model.title}`);
  parts.push('');
  parts.push('## 今日重点');
  const focusLines: string[] = [];
  if (model.focus && model.focus.trim()) {
    focusLines.push(`- ${model.focus.trim()} <!-- focus -->`);
  }
  for (const s of model.schedules) {
    if (s.focus) {
      focusLines.push(`- ${s.startTime}-${s.endTime} ${s.title} <!-- sid:${s.id} -->`);
    }
  }
  parts.push(focusLines.length ? focusLines.join('\n') : '暂无今日重点。');

  parts.push('');
  parts.push('## 今日日程');
  const tasks = model.schedules.filter((s) => s.type !== 'note');
  const notes = model.schedules.filter((s) => s.type === 'note');
  const taskLines = tasks.map(
    (s) =>
      `- [${s.completed ? 'x' : ' '}] ${s.startTime}-${s.endTime} ${s.title}（${s.category}） <!-- sid:${s.id} -->`,
  );
  parts.push(taskLines.length ? taskLines.join('\n') : '暂无日程。');
  if (notes.length) {
    parts.push('### 时间记录');
    parts.push(
      notes
        .map((s) => `- ${s.startTime}-${s.endTime} ${s.title}（记录） <!-- sid:${s.id} -->`)
        .join('\n'),
    );
  }

  parts.push('');
  parts.push('## 快速记录');
  const qnLines = model.quickNotes.map(
    (q) => `- ${quickNoteTime(q.createdAt)} ${q.content} <!-- qn:${q.id} -->`,
  );
  parts.push(qnLines.length ? qnLines.join('\n') : '暂无快速记录。');

  parts.push('');
  parts.push('## 今日复盘');
  if (model.review.length) {
    parts.push(
      model.review
        .map((r) => {
          const head = `### ${r.title} <!-- rv:${r.questionId} -->`;
          const body = r.content && r.content.trim() ? indentMultiline(r.content) : '暂无。';
          return `${head}\n${body}`;
        })
        .join('\n\n'),
    );
  } else {
    parts.push('暂无复盘内容。');
  }

  return parts.join('\n');
}

/** 构造空白日期模型（标题由调用方按「YYYY年M月D日 周X」格式传入）。 */
export function createEmptyDailyDoc(title: string): DailyDocModel {
  return {
    title,
    focus: null,
    schedules: [],
    quickNotes: [],
    review: [],
  };
}

/**
 * 序列化「纯净」Daily Markdown（docs/09 §12.1 沉淀文法）：**零 `<!-- -->` 程序标记**，
 * 标准 Markdown，兼容 AI 直读与 Obsidian/Typora。结构段序、占位文案与 serializeDailyDoc 一致，
 * 仅去掉所有行尾稳定 ID 注释（focus/sid/qn/rv）。沉淀动作（docs/09 P2）的输出产物。
 *
 * 与 serializeDailyDoc 的唯一差异：行尾不带注释。重点↔日程的关联在纯净文法中靠
 * 「同时间段+同标题」的内容指纹隐含表达（回看对账 P3 靠指纹匹配，不靠 ID）。
 */
export function serializeCleanDailyDoc(model: DailyDocModel): string {
  const parts: string[] = [];

  parts.push(`# ${model.title}`);
  parts.push('');
  parts.push('## 今日重点');
  const focusLines: string[] = [];
  if (model.focus && model.focus.trim()) {
    focusLines.push(`- ${model.focus.trim()}`);
  }
  for (const s of model.schedules) {
    if (s.focus) {
      focusLines.push(`- ${s.startTime}-${s.endTime} ${s.title}`);
    }
  }
  parts.push(focusLines.length ? focusLines.join('\n') : '暂无今日重点。');

  parts.push('');
  parts.push('## 今日日程');
  const tasks = model.schedules.filter((s) => s.type !== 'note');
  const notes = model.schedules.filter((s) => s.type === 'note');
  const taskLines = tasks.map(
    (s) => `- [${s.completed ? 'x' : ' '}] ${s.startTime}-${s.endTime} ${s.title}（${s.category}）`,
  );
  parts.push(taskLines.length ? taskLines.join('\n') : '暂无日程。');
  if (notes.length) {
    parts.push('### 时间记录');
    parts.push(notes.map((s) => `- ${s.startTime}-${s.endTime} ${s.title}（记录）`).join('\n'));
  }

  parts.push('');
  parts.push('## 快速记录');
  const qnLines = model.quickNotes.map((q) => `- ${quickNoteTime(q.createdAt)} ${q.content}`);
  parts.push(qnLines.length ? qnLines.join('\n') : '暂无快速记录。');

  parts.push('');
  parts.push('## 今日复盘');
  if (model.review.length) {
    parts.push(
      model.review
        .map((r) => {
          const head = `### ${r.title}`;
          const body = r.content && r.content.trim() ? indentMultiline(r.content) : '暂无。';
          return `${head}\n${body}`;
        })
        .join('\n\n'),
    );
  } else {
    parts.push('暂无复盘内容。');
  }

  return parts.join('\n');
}

/**
 * 解析「纯净」Daily Markdown（docs/09 §12.1 沉淀文法产物，回看对账 P3 用）。
 *
 * 与 parseDailyDoc 的核心差异：纯净文法**无行尾注释**，实体无稳定 ID。
 * 解析时实体 ID 用 newId() 临时分配（纯读取视图，不落库），dirty 恒为 false（无需写回补 ID）。
 * 重点↔日程关联靠「同时间段+同标题」内容指纹推断：若重点行匹配某日程的时间段，置该日程 focus。
 *
 * P1 提供骨架（结构同 parseDailyDoc 但去掉注释解析逻辑）；P3 回看对账完善内容指纹匹配。
 */
export function parseCleanMd(md: string, opts?: { date?: string }): ParseResult {
  const date = opts?.date ?? '';
  const lines = md.split(/\r?\n/);

  let title = '';
  let focus: string | null = null;
  const schedules: Schedule[] = [];
  const quickNotes: QuickNote[] = [];
  const review: ReviewEntry[] = [];
  /** 重点段里匹配日程时间段未命中的行（自由文本重点候选）。 */
  const focusScheduleRefs: { start: string; end: string; title: string }[] = [];

  let section: Section = 'none';
  let currentReview: ReviewEntry | null = null;
  let order = 0;

  for (const rawLine of lines) {
    const trimmed = rawLine.trim();
    if (trimmed === '') continue;

    if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
      title = trimmed.slice(2).trim();
      continue;
    }
    if (trimmed === '## 今日重点') {
      section = 'focus';
      continue;
    }
    if (trimmed === '## 今日日程') {
      section = 'schedule';
      continue;
    }
    if (trimmed === '## 快速记录') {
      section = 'quicknote';
      continue;
    }
    if (trimmed === '## 今日复盘') {
      if (currentReview) review.push(currentReview);
      currentReview = null;
      section = 'review';
      continue;
    }
    if (trimmed === '### 时间记录' && section === 'schedule') {
      section = 'note';
      continue;
    }
    if (trimmed.startsWith('### ') && section === 'review') {
      if (currentReview) review.push(currentReview);
      const reviewTitle = trimmed.replace(/^###\s+/, '').trim();
      currentReview = { questionId: newId(), title: reviewTitle, content: '' };
      continue;
    }

    switch (section) {
      case 'focus': {
        if (!/^- /.test(trimmed)) continue; // 占位行忽略
        const text = trimmed.replace(/^-\s+/, '').trim();
        // 尝试匹配「HH:MM-HH:MM 标题」格式（日程重点引用）
        const refMatch = text.match(/^(\d{1,2}:\d{2})-(\d{1,2}:\d{2}) (.+)$/);
        if (refMatch) {
          focusScheduleRefs.push({ start: refMatch[1], end: refMatch[2], title: refMatch[3].trim() });
        } else if (focus === null) {
          focus = text;
        }
        continue;
      }
      case 'schedule': {
        const sch = parseCleanScheduleLine(trimmed, 'task', date, order);
        if (sch) {
          schedules.push(sch);
          order += 1;
        }
        continue;
      }
      case 'note': {
        const sch = parseCleanScheduleLine(trimmed, 'note', date, order);
        if (sch) {
          schedules.push(sch);
          order += 1;
        }
        continue;
      }
      case 'quicknote': {
        const qn = parseCleanQuickNoteLine(trimmed, date);
        if (qn) quickNotes.push(qn);
        continue;
      }
      case 'review': {
        if (currentReview && /^\s+\S/.test(rawLine)) {
          const lineText = rawLine.trim();
          if (lineText && lineText !== '暂无。') {
            currentReview.content = currentReview.content
              ? `${currentReview.content}\n${lineText}`
              : lineText;
          }
        }
        continue;
      }
      default:
        continue;
    }
  }
  if (currentReview) review.push(currentReview);

  // 内容指纹匹配：重点引用（时间段+标题）命中日程 → 置 focus
  for (const ref of focusScheduleRefs) {
    const hit = schedules.find(
      (s) => s.startTime === ref.start && s.endTime === ref.end && s.title === ref.title,
    );
    if (hit) hit.focus = true;
  }

  return {
    model: { title, focus, schedules, quickNotes, review },
    dirty: false, // 纯净文法无 ID 需补，恒不脏
  };
}

/** 解析纯净日程行（无注释版本，ID 用 newId 临时分配）。 */
function parseCleanScheduleLine(
  line: string,
  type: ScheduleType,
  date: string,
  order: number,
): Schedule | null {
  let rest: string | null = null;
  let mark: string | null = null;
  if (type === 'task') {
    const tm = line.match(TASK_HEAD_RE);
    if (!tm) return null;
    mark = tm[1];
    rest = tm[2];
  } else {
    const nm = line.match(BULLET_RE);
    if (!nm) return null;
    rest = nm[1];
  }
  const rm = rest.match(RANGE_RE);
  if (!rm) return null;
  const [, start, end, title, categoryRaw] = rm;
  const category = type === 'note' ? normalizeCategory(categoryRaw) : normalizeCategory(categoryRaw);
  return {
    id: newId(),
    title: title.trim(),
    completed: type === 'task' ? mark !== null && mark.toLowerCase() === 'x' : false,
    category,
    categoryColor: SCHEDULE_CATEGORY_COLORS[category],
    type,
    startTime: start,
    endTime: end,
    date,
    sortOrder: order,
  };
}

/** 解析纯净快速记录行（无注释版本，ID 用 newId 临时分配）。 */
function parseCleanQuickNoteLine(line: string, date: string): QuickNote | null {
  const m = line.match(BULLET_RE);
  if (!m) return null;
  const qm = m[1].match(QUICK_RE);
  if (!qm) return null;
  const [, time, content] = qm;
  const createdAt = `${date}T${time}:00.000`;
  return {
    id: newId(),
    date,
    content: content.trim(),
    sourceDevice: 'desktop',
    status: 'active',
    createdAt,
    updatedAt: createdAt,
  };
}
