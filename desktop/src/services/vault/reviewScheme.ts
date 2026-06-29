/**
 * 复盘方案（scheme）本地化存储：方案（题目/排序/必填/字数）无天然 Markdown 位置，
 * 故作为普通 vault 文件 `Reviews/scheme.md` 同步，内嵌 ```json 代码块承载结构化数据。
 * vault 引擎只同步 .md，故 JSON 必须包在 .md 载体内。
 *
 * 方案/题目 ID 稳定（custom 用 UUID），保证历史每日复盘 `<!-- rv:<questionId> -->` 的对应关系：
 * 重命名题目不改 ID → 历史仍可匹配；删题/切方案的历史复盘答案仍留在各自日期的 Daily MD 里（可读）。
 */
import type {
  CreateReviewQuestionSchemePayload,
  ReviewQuestion,
  ReviewQuestionScheme,
  UpdateReviewQuestionSchemePayload,
} from '../../shared/types/dailyReview';

/** scheme 文件在 vault 内的相对路径。 */
export const SCHEME_VAULT_PATH = 'Reviews/scheme.md';

export interface ReviewSchemeStore {
  activeSchemeId: string;
  schemes: ReviewQuestionScheme[];
}

export const OFFICIAL_SCHEME_ID = 'scheme-official-default';

/** 官方默认方案：题目 ID 稳定（official-*），历史复盘可永久匹配。 */
export const DEFAULT_REVIEW_SCHEMES: ReviewQuestionScheme[] = [
  {
    id: OFFICIAL_SCHEME_ID,
    name: '官方默认方案',
    source: 'official',
    isDefault: true,
    questions: [
      {
        id: 'official-done',
        title: '今天完成了什么？',
        placeholder: '写下今天实际完成的事情，可以用项目符号记录...',
        required: true,
        maxLength: 500,
        sortOrder: 1,
      },
      {
        id: 'official-undone',
        title: '今天没完成什么？',
        placeholder: '写下未完成的事项、原因或需要继续推进的部分...',
        required: true,
        maxLength: 500,
        sortOrder: 2,
      },
      {
        id: 'official-gain',
        title: '今天有什么收获？',
        placeholder: '记录今天的新发现、经验、复盘结论或一个小提醒...',
        required: true,
        maxLength: 500,
        sortOrder: 3,
      },
      {
        id: 'official-tomorrow',
        title: '明天最重要的一件事是什么？',
        placeholder: '只写一件最值得优先处理的事，让明天更清楚...',
        required: true,
        maxLength: 500,
        sortOrder: 4,
      },
    ],
  },
  {
    id: 'scheme-custom-light',
    name: '我的轻量复盘',
    source: 'custom',
    isDefault: false,
    questions: [
      {
        id: 'custom-progress',
        title: '今天最值得记录的进展？',
        placeholder: '记录一个最有推进感的进展...',
        required: true,
        maxLength: 500,
        sortOrder: 1,
      },
      {
        id: 'custom-blocker',
        title: '今天最大的阻碍是什么？',
        placeholder: '写下阻碍、卡点或让你分心的事情...',
        required: false,
        maxLength: 500,
        sortOrder: 2,
      },
      {
        id: 'custom-next',
        title: '明天先做哪一步？',
        placeholder: '给明天留一个可以直接开始的第一步...',
        required: true,
        maxLength: 500,
        sortOrder: 3,
      },
    ],
  },
];

export const DEFAULT_REVIEW_SCHEME_STORE: ReviewSchemeStore = {
  activeSchemeId: OFFICIAL_SCHEME_ID,
  schemes: DEFAULT_REVIEW_SCHEMES.map((scheme) => ({
    ...scheme,
    questions: scheme.questions.map((question) => ({ ...question })),
  })),
};

const JSON_BLOCK_RE = /```json\s*([\s\S]*?)```/;

/** 从 scheme.md 提取 JSON 并解析；格式异常回退默认方案。 */
export function parseSchemeDoc(md: string): ReviewSchemeStore {
  if (!md || !md.trim()) return cloneStore(DEFAULT_REVIEW_SCHEME_STORE);
  const match = md.match(JSON_BLOCK_RE);
  if (!match) return cloneStore(DEFAULT_REVIEW_SCHEME_STORE);
  try {
    const parsed = JSON.parse(match[1]) as Partial<ReviewSchemeStore>;
    if (!parsed || !Array.isArray(parsed.schemes) || parsed.schemes.length === 0) {
      return cloneStore(DEFAULT_REVIEW_SCHEME_STORE);
    }
    return {
      activeSchemeId:
        typeof parsed.activeSchemeId === 'string' && parsed.schemes.some((s) => s.id === parsed.activeSchemeId)
          ? parsed.activeSchemeId
          : parsed.schemes[0].id,
      schemes: parsed.schemes.map(cloneScheme),
    };
  } catch {
    return cloneStore(DEFAULT_REVIEW_SCHEME_STORE);
  }
}

/** 序列化为 scheme.md（Markdown 载体 + ```json 块）。 */
export function serializeSchemeDoc(data: ReviewSchemeStore): string {
  return [
    '# LifeScale 复盘方案',
    '',
    '> 本文件由 LifeScale 维护，存放复盘题目方案（官方 + 自定义）。可在应用「复盘」页编辑，请勿手动改动下方 JSON 结构。',
    '',
    '```json',
    JSON.stringify(data, null, 2),
    '```',
    '',
  ].join('\n');
}

export function cloneStore(store: ReviewSchemeStore): ReviewSchemeStore {
  return {
    activeSchemeId: store.activeSchemeId,
    schemes: store.schemes.map(cloneScheme),
  };
}

export function cloneScheme(scheme: ReviewQuestionScheme): ReviewQuestionScheme {
  return { ...scheme, questions: scheme.questions.map((question) => ({ ...question })) };
}

// ---- 方案规范化（供 useReviewScheme 的增删改使用） ----

export function normalizeSchemeName(name: string): string {
  return name.trim().slice(0, 24);
}

export function normalizeQuestions(
  questions: CreateReviewQuestionSchemePayload['questions'],
): ReviewQuestion[] {
  return questions
    .slice(0, 4)
    .map((question, index) => ({
      id: question.id ?? newId(),
      title: question.title.trim(),
      placeholder: question.placeholder.trim() || '请在此输入你的思考...',
      required: question.required,
      maxLength: Math.min(Math.max(question.maxLength ?? 500, 100), 1000),
      sortOrder: index + 1,
    }))
    .filter((question) => question.title.length > 0);
}

/** 生成稳定 ID（custom 方案/题目用）。 */
export function newId(): string {
  try {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID();
    }
  } catch {
    /* fallthrough */
  }
  return `id-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/** 由 payload 构造新 custom 方案（规范化 + 稳定 ID）。 */
export function buildSchemeFromPayload(payload: CreateReviewQuestionSchemePayload): ReviewQuestionScheme | null {
  const name = normalizeSchemeName(payload.name);
  const questions = normalizeQuestions(payload.questions);
  if (!name || questions.length === 0) return null;
  return { id: newId(), name, source: 'custom', isDefault: false, questions };
}

/** 由更新 payload 构造方案（保留原 id；official 不可改）。 */
export function applySchemeUpdate(
  current: ReviewQuestionScheme,
  payload: UpdateReviewQuestionSchemePayload,
): ReviewQuestionScheme | null {
  if (current.source === 'official') return null;
  const name = normalizeSchemeName(payload.name);
  const questions = normalizeQuestions(payload.questions);
  if (!name || questions.length === 0) return null;
  return { ...current, name, questions };
}
