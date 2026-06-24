import { describe, it, expect } from 'vitest';
import {
  SCHEME_VAULT_PATH,
  applySchemeUpdate,
  buildSchemeFromPayload,
  cloneStore,
  normalizeQuestions,
  parseSchemeDoc,
  serializeSchemeDoc,
  DEFAULT_REVIEW_SCHEME_STORE,
  OFFICIAL_SCHEME_ID,
} from './reviewScheme';

describe('reviewScheme parse/serialize', () => {
  it('往返等价：parse(serialize(store)) 深相等', () => {
    const store = cloneStore(DEFAULT_REVIEW_SCHEME_STORE);
    const md = serializeSchemeDoc(store);
    const reparsed = parseSchemeDoc(md);
    expect(reparsed).toEqual(store);
  });

  it('序列化产出 ```json 块且含 activeSchemeId/schemes', () => {
    const md = serializeSchemeDoc(DEFAULT_REVIEW_SCHEME_STORE);
    expect(md).toContain('```json');
    expect(md).toContain('"activeSchemeId"');
    expect(md).toContain('"schemes"');
    expect(md).toContain(OFFICIAL_SCHEME_ID);
  });

  it('空/无 JSON 块/非法 JSON → 回退默认方案', () => {
    expect(parseSchemeDoc('')).toEqual(DEFAULT_REVIEW_SCHEME_STORE);
    expect(parseSchemeDoc('# 只有标题\n\n无 JSON')).toEqual(DEFAULT_REVIEW_SCHEME_STORE);
    expect(parseSchemeDoc('```json\n{不是合法json\n```')).toEqual(DEFAULT_REVIEW_SCHEME_STORE);
  });

  it('activeSchemeId 指向不存在的方案 → 回退首个方案', () => {
    const md = serializeSchemeDoc({
      activeSchemeId: '不存在',
      schemes: DEFAULT_REVIEW_SCHEME_STORE.schemes,
    });
    const parsed = parseSchemeDoc(md);
    expect(parsed.activeSchemeId).toBe(parsed.schemes[0].id);
  });

  it('保留 custom 方案稳定题目 ID（历史 rv: 可匹配）', () => {
    const store: typeof DEFAULT_REVIEW_SCHEME_STORE = {
      activeSchemeId: 'sch-x',
      schemes: [
        {
          id: 'sch-x',
          name: '我的方案',
          source: 'custom',
          isDefault: false,
          questions: [{ id: 'q-stable', title: '题', placeholder: 'p', required: true, maxLength: 500, sortOrder: 1 }],
        },
      ],
    };
    const reparsed = parseSchemeDoc(serializeSchemeDoc(store));
    expect(reparsed.schemes[0].questions[0].id).toBe('q-stable');
  });
});

describe('reviewScheme 规范化', () => {
  it('normalizeQuestions：补 sortOrder、截断 maxLength、过滤空标题、保留传入 id', () => {
    const questions = normalizeQuestions([
      { id: 'keep', title: '保留', placeholder: '', required: true, maxLength: 99999 },
      { title: '   ', placeholder: 'x', required: false }, // 空标题被过滤
    ]);
    expect(questions).toHaveLength(1);
    expect(questions[0].id).toBe('keep');
    expect(questions[0].sortOrder).toBe(1);
    expect(questions[0].maxLength).toBe(1000);
    expect(questions[0].placeholder).toBe('请在此输入你的思考...');
  });

  it('buildSchemeFromPayload：空名称/无题目返回 null，否则生成 custom 方案', () => {
    expect(buildSchemeFromPayload({ name: '', questions: [{ title: 'x', placeholder: '', required: true }] })).toBeNull();
    expect(
      buildSchemeFromPayload({ name: '方案', questions: [{ title: '', placeholder: '', required: true }] }),
    ).toBeNull();
    const scheme = buildSchemeFromPayload({
      name: '我的方案',
      questions: [{ title: '题一', placeholder: '', required: true }],
    });
    expect(scheme).not.toBeNull();
    expect(scheme!.source).toBe('custom');
    expect(scheme!.questions).toHaveLength(1);
  });

  it('applySchemeUpdate：official 方案不可改', () => {
    const official = DEFAULT_REVIEW_SCHEME_STORE.schemes.find((s) => s.source === 'official')!;
    expect(applySchemeUpdate(official, { id: official.id, name: '改名', questions: official.questions })).toBeNull();
  });

  it('SCHEME_VAULT_PATH 为 Reviews/scheme.md（vault 内 .md 才会被引擎同步）', () => {
    expect(SCHEME_VAULT_PATH).toBe('Reviews/scheme.md');
  });
});
