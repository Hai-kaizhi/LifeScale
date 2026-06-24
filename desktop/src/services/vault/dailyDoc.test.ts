import { describe, it, expect } from 'vitest';
import {
  parseCleanMd,
  parseDailyDoc,
  serializeCleanDailyDoc,
  serializeDailyDoc,
  type DailyDocModel,
} from './dailyDoc';

const DATE = '2026-06-17';

/** 与 docs/06 §3.3 一致的带 ID 完整示例。 */
const SAMPLE = `# 2026年6月17日 周二

## 今日重点
- 写完设计文档 <!-- focus -->
- 09:00-10:00 写周报 <!-- sid:aaa -->

## 今日日程
- [x] 09:00-10:00 写周报（工作） <!-- sid:aaa -->
- [ ] 14:00-15:00 健身（生活） <!-- sid:bbb -->

### 时间记录
- 10:00-10:30 开会（记录） <!-- sid:ccc -->

## 快速记录
- 09:30 想到一个点子 <!-- qn:q1 -->
- 11:15 买咖啡 <!-- qn:q2 -->

## 今日复盘
### 今天完成了什么 <!-- rv:r1 -->
  写完了文档
  还测了一遍

### 哪里可以改进 <!-- rv:r2 -->
  早起
`;

const SEED = `# 2026年6月17日 周二

## 今日重点
暂无今日重点。

## 今日日程
暂无日程。

## 快速记录
暂无快速记录。

## 今日复盘
暂无复盘内容。`;

/** 深比较两个模型（忽略 undefined 字段差异）。 */
function modelsEqual(a: DailyDocModel, b: DailyDocModel): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

describe('parseDailyDoc / serializeDailyDoc', () => {
  it('空模板 → 空模型，不脏', () => {
    const { model, dirty } = parseDailyDoc(SEED, { date: DATE });
    expect(model.title).toBe('2026年6月17日 周二');
    expect(model.focus).toBeNull();
    expect(model.schedules).toHaveLength(0);
    expect(model.quickNotes).toHaveLength(0);
    expect(model.review).toHaveLength(0);
    expect(dirty).toBe(false);
  });

  it('空模型序列化 → 含占位、不带注释', () => {
    const md = serializeDailyDoc({
      title: '2026年6月17日 周二',
      focus: null,
      schedules: [],
      quickNotes: [],
      review: [],
    });
    expect(md).toContain('## 今日重点\n暂无今日重点。');
    expect(md).toContain('## 今日日程\n暂无日程。');
    expect(md).toContain('## 快速记录\n暂无快速记录。');
    expect(md).toContain('## 今日复盘\n暂无复盘内容。');
    expect(md).not.toContain('<!--');
  });

  it('重点 + 日程同名：靠 sid 关联，自由重点单独保留', () => {
    const { model } = parseDailyDoc(SAMPLE, { date: DATE });
    expect(model.focus).toBe('写完设计文档');
    const weekly = model.schedules.find((s) => s.id === 'aaa');
    expect(weekly).toBeDefined();
    expect(weekly!.title).toBe('写周报'); // 与重点引用行同名
    expect(weekly!.focus).toBe(true); // 被重点段引用 → focus
    expect(weekly!.completed).toBe(true);
    expect(weekly!.type).toBe('task');
    expect(weekly!.category).toBe('工作');
    const gym = model.schedules.find((s) => s.id === 'bbb');
    expect(gym!.completed).toBe(false);
    expect(gym!.focus).toBeFalsy();
  });

  it('时间记录子段 → type=note', () => {
    const { model } = parseDailyDoc(SAMPLE, { date: DATE });
    const meeting = model.schedules.find((s) => s.id === 'ccc');
    expect(meeting).toBeDefined();
    expect(meeting!.type).toBe('note');
    expect(meeting!.startTime).toBe('10:00');
    expect(meeting!.endTime).toBe('10:30');
  });

  it('快速记录：内容与由 createdAt 派生的 HH:mm', () => {
    const { model } = parseDailyDoc(SAMPLE, { date: DATE });
    expect(model.quickNotes).toHaveLength(2);
    const idea = model.quickNotes.find((q) => q.id === 'q1');
    expect(idea!.content).toBe('想到一个点子');
    expect(idea!.createdAt).toBe('2026-06-17T09:30:00.000');
  });

  it('多行复盘答案（缩进）正确合并', () => {
    const { model } = parseDailyDoc(SAMPLE, { date: DATE });
    expect(model.review).toHaveLength(2);
    const r1 = model.review.find((r) => r.questionId === 'r1');
    expect(r1!.title).toBe('今天完成了什么');
    expect(r1!.content).toBe('写完了文档\n还测了一遍');
    const r2 = model.review.find((r) => r.questionId === 'r2');
    expect(r2!.content).toBe('早起');
  });

  it('段内行序 = sortOrder', () => {
    const { model } = parseDailyDoc(SAMPLE, { date: DATE });
    const tasks = model.schedules.filter((s) => s.type !== 'note');
    expect(tasks[0].sortOrder).toBe(0);
    expect(tasks[1].sortOrder).toBe(1);
    const note = model.schedules.find((s) => s.type === 'note');
    expect(note!.sortOrder).toBe(2);
  });

  it('移动行顺序：重排后序列化→解析顺序保留', () => {
    const parsed = parseDailyDoc(SAMPLE, { date: DATE }).model;
    // 重排：把 bbb 提到 aaa 前
    const aaa = parsed.schedules.find((s) => s.id === 'aaa')!;
    const bbb = parsed.schedules.find((s) => s.id === 'bbb')!;
    const ccc = parsed.schedules.find((s) => s.id === 'ccc')!;
    const reordered: DailyDocModel = {
      ...parsed,
      schedules: [bbb, aaa, ccc],
    };
    reordered.schedules.forEach((s, i) => {
      s.sortOrder = i;
    });
    const md = serializeDailyDoc(reordered);
    const { model } = parseDailyDoc(md, { date: DATE });
    const tasks = model.schedules.filter((s) => s.type !== 'note');
    expect(tasks[0].id).toBe('bbb');
    expect(tasks[1].id).toBe('aaa');
  });

  it('删除行：序列化后该条消失', () => {
    const parsed = parseDailyDoc(SAMPLE, { date: DATE }).model;
    const deleted: DailyDocModel = {
      ...parsed,
      schedules: parsed.schedules.filter((s) => s.id !== 'bbb'),
    };
    const md = serializeDailyDoc(deleted);
    const { model } = parseDailyDoc(md, { date: DATE });
    expect(model.schedules.find((s) => s.id === 'bbb')).toBeUndefined();
    expect(model.schedules).toHaveLength(2);
  });

  it('往返等价：serialize(parse(serialize(parse(x)))) 稳定且不再 dirty', () => {
    const once = serializeDailyDoc(parseDailyDoc(SAMPLE, { date: DATE }).model);
    const twice = serializeDailyDoc(parseDailyDoc(once, { date: DATE }).model);
    expect(twice).toBe(once);
    expect(parseDailyDoc(once, { date: DATE }).dirty).toBe(false);
    // 模型等价
    expect(modelsEqual(parseDailyDoc(once, { date: DATE }).model, parseDailyDoc(twice, { date: DATE }).model)).toBe(true);
  });

  it('老文件无 ID → 补 ID 并标 dirty；补完后再解析不脏', () => {
    const OLD = `# 2026年6月17日 周二

## 今日重点
- 写完设计文档

## 今日日程
- [x] 09:00-10:00 写周报（工作）

## 快速记录
- 09:30 想到一个点子

## 今日复盘
### 今天完成了什么
  写完了文档
`;
    const res = parseDailyDoc(OLD, { date: DATE });
    expect(res.dirty).toBe(true);
    expect(res.model.focus).toBe('写完设计文档');
    expect(res.model.schedules[0].id).toBeTruthy();
    expect(res.model.quickNotes[0].id).toBeTruthy();
    expect(res.model.review[0].questionId).toBeTruthy();

    const withIds = serializeDailyDoc(res.model);
    const reparsed = parseDailyDoc(withIds, { date: DATE });
    expect(reparsed.dirty).toBe(false);
    // 内容保留
    expect(reparsed.model.schedules[0].title).toBe('写周报');
    expect(reparsed.model.review[0].content).toBe('写完了文档');
  });

  it('容错：无段间空行（REST 旧生成器格式）也能解析', () => {
    const noBlanks = SAMPLE.replace(/\n\n/g, '\n');
    const { model } = parseDailyDoc(noBlanks, { date: DATE });
    expect(model.schedules).toHaveLength(3);
    expect(model.quickNotes).toHaveLength(2);
    expect(model.review).toHaveLength(2);
  });
});

describe('serializeCleanDailyDoc / parseCleanMd（docs/09 §12.1 沉淀纯净文法）', () => {
  /** 与 docs/09 §12.1 示例对齐的纯净样本（零注释）。 */
  const CLEAN_SAMPLE = `# 2026年6月17日 周二

## 今日重点
- 写完设计文档
- 09:00-10:00 写周报

## 今日日程
- [x] 09:00-10:00 写周报（工作）
- [ ] 14:00-15:00 健身（生活）

### 时间记录
- 10:00-10:30 开会（记录）

## 快速记录
- 09:30 想到一个点子
- 11:15 买咖啡

## 今日复盘
### 今天完成了什么
  写完了文档
  还测了一遍

### 哪里可以改进
  早起
`;

  it('纯净序列化：零 `<!-- -->` 注释', () => {
    const model = parseDailyDoc(SAMPLE, { date: DATE }).model;
    const md = serializeCleanDailyDoc(model);
    expect(md).not.toContain('<!--');
    expect(md).toContain('## 今日重点');
    expect(md).toContain('## 今日日程');
    expect(md).toContain('### 时间记录');
    expect(md).toContain('## 快速记录');
    expect(md).toContain('## 今日复盘');
  });

  it('空模型纯净序列化仍含占位、零注释', () => {
    const md = serializeCleanDailyDoc({
      title: '2026年6月17日 周二',
      focus: null,
      schedules: [],
      quickNotes: [],
      review: [],
    });
    expect(md).toContain('暂无今日重点。');
    expect(md).toContain('暂无日程。');
    expect(md).not.toContain('<!--');
  });

  it('parseCleanMd 解析纯净文法：实体内容等价（标题/时间段/分类/完成/重点/复盘）', () => {
    const { model, dirty } = parseCleanMd(CLEAN_SAMPLE, { date: DATE });
    expect(dirty).toBe(false); // 纯净文法无 ID 需补
    expect(model.focus).toBe('写完设计文档');
    expect(model.schedules).toHaveLength(3);
    const weekly = model.schedules.find((s) => s.startTime === '09:00' && s.title === '写周报');
    expect(weekly).toBeDefined();
    expect(weekly!.completed).toBe(true);
    expect(weekly!.category).toBe('工作');
    expect(weekly!.type).toBe('task');
    // 重点引用靠内容指纹匹配（同时间段+同标题）→ focus
    expect(weekly!.focus).toBe(true);
    const gym = model.schedules.find((s) => s.startTime === '14:00');
    expect(gym!.completed).toBe(false);
    const meeting = model.schedules.find((s) => s.type === 'note');
    expect(meeting!.startTime).toBe('10:00');
    expect(model.quickNotes).toHaveLength(2);
    expect(model.quickNotes[0].content).toBe('想到一个点子');
    expect(model.quickNotes[0].createdAt).toBe('2026-06-17T09:30:00.000');
    expect(model.review).toHaveLength(2);
    expect(model.review[0].title).toBe('今天完成了什么');
    expect(model.review[0].content).toBe('写完了文档\n还测了一遍');
  });

  it('纯净往返：serializeClean(parseClean(x)) 实体内容等价', () => {
    const parsed = parseCleanMd(CLEAN_SAMPLE, { date: DATE }).model;
    const reserialized = serializeCleanDailyDoc(parsed);
    const reparsed = parseCleanMd(reserialized, { date: DATE }).model;
    // 比较关键字段（ID 因 newId 每次不同，跳过）
    expect(reparsed.focus).toBe(parsed.focus);
    expect(reparsed.schedules.map((s) => `${s.startTime}-${s.endTime} ${s.title} ${s.category} ${s.completed}`))
      .toEqual(parsed.schedules.map((s) => `${s.startTime}-${s.endTime} ${s.title} ${s.category} ${s.completed}`));
    expect(reparsed.quickNotes.map((q) => `${q.createdAt} ${q.content}`))
      .toEqual(parsed.quickNotes.map((q) => `${q.createdAt} ${q.content}`));
    expect(reparsed.review.map((r) => `${r.title}|${r.content}`))
      .toEqual(parsed.review.map((r) => `${r.title}|${r.content}`));
  });
});
