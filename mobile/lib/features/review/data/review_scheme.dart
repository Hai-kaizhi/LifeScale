import 'dart:convert';

/// 复盘方案（scheme）解析与序列化，1:1 移植桌面端
/// `desktop/src/services/vault/reviewScheme.ts`。
///
/// 方案无天然 Markdown 位置，故作为普通 vault 文件 `Reviews/scheme.md` 同步，
/// 内嵌 ```json 代码块承载结构化数据（JSON-in-Markdown）。
///
/// 题目 ID 稳定（official-* 永久 / custom 用 UUID），保证历史每日复盘
/// `<!-- rv:<questionId> -->` 永久匹配：重命名题目不改 ID → 历史仍可读；
/// 删题/切方案的历史答案留在各自日期的 Daily MD 里仍可读。

/// 方案文件在 vault 内的相对路径（与桌面端 `SCHEME_VAULT_PATH` 一致）。
const String schemeVaultPath = 'Reviews/scheme.md';

/// 官方默认方案 ID。
const String officialSchemeId = 'scheme-official-default';

/// 单个复盘题目。
class ReviewQuestion {
  const ReviewQuestion({
    required this.id,
    required this.title,
    this.placeholder,
    required this.required,
    required this.maxLength,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String? placeholder;
  final bool required;
  final int maxLength;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'placeholder': placeholder,
        'required': required,
        'maxLength': maxLength,
        'sortOrder': sortOrder,
      };

  factory ReviewQuestion.fromJson(Map<String, dynamic> json) => ReviewQuestion(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        placeholder: json['placeholder']?.toString(),
        required: json['required'] == true,
        maxLength: json['maxLength'] is int
            ? json['maxLength'] as int
            : int.tryParse(json['maxLength']?.toString() ?? '') ?? 500,
        sortOrder: json['sortOrder'] is int
            ? json['sortOrder'] as int
            : int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      );
}

/// 一个复盘方案（含多道题目）。
class ReviewQuestionScheme {
  const ReviewQuestionScheme({
    required this.id,
    required this.name,
    required this.source,
    required this.isDefault,
    required this.questions,
  });

  final String id;
  final String name;
  final String source; // official / custom
  final bool isDefault;
  final List<ReviewQuestion> questions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source,
        'isDefault': isDefault,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory ReviewQuestionScheme.fromJson(Map<String, dynamic> json) =>
      ReviewQuestionScheme(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        source: (json['source'] ?? 'custom').toString(),
        isDefault: json['isDefault'] == true,
        questions: ((json['questions'] ?? const <dynamic>[]) as List<dynamic>)
            .map((e) => ReviewQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 方案存储：activeSchemeId + 全部方案。
class ReviewSchemeStore {
  const ReviewSchemeStore({
    required this.activeSchemeId,
    required this.schemes,
  });

  final String activeSchemeId;
  final List<ReviewQuestionScheme> schemes;

  /// 当前激活方案；找不到则回退第一个方案。
  ReviewQuestionScheme get activeScheme {
    return schemes.firstWhere(
      (s) => s.id == activeSchemeId,
      orElse: () => schemes.isNotEmpty
          ? schemes.first
          : defaultSchemeStore.schemes.first,
    );
  }
}

/// 官方默认方案：题目 ID 稳定（official-*），历史复盘可永久匹配。
final List<ReviewQuestionScheme> defaultSchemes = [
  ReviewQuestionScheme(
    id: officialSchemeId,
    name: '官方默认方案',
    source: 'official',
    isDefault: true,
    questions: const [
      ReviewQuestion(
        id: 'official-done',
        title: '今天完成了什么？',
        placeholder: '写下今天实际完成的事情，可以用项目符号记录...',
        required: true,
        maxLength: 500,
        sortOrder: 1,
      ),
      ReviewQuestion(
        id: 'official-undone',
        title: '今天没完成什么？',
        placeholder: '写下未完成的事项、原因或需要继续推进的部分...',
        required: true,
        maxLength: 500,
        sortOrder: 2,
      ),
      ReviewQuestion(
        id: 'official-gain',
        title: '今天有什么收获？',
        placeholder: '记录今天的新发现、经验、复盘结论或一个小提醒...',
        required: true,
        maxLength: 500,
        sortOrder: 3,
      ),
      ReviewQuestion(
        id: 'official-tomorrow',
        title: '明天最重要的一件事是什么？',
        placeholder: '只写一件最值得优先处理的事，让明天更清楚...',
        required: true,
        maxLength: 500,
        sortOrder: 4,
      ),
    ],
  ),
  ReviewQuestionScheme(
    id: 'scheme-custom-light',
    name: '我的轻量复盘',
    source: 'custom',
    isDefault: false,
    questions: const [
      ReviewQuestion(
        id: 'custom-progress',
        title: '今天最值得记录的进展？',
        placeholder: '记录一个最有推进感的进展...',
        required: true,
        maxLength: 500,
        sortOrder: 1,
      ),
      ReviewQuestion(
        id: 'custom-blocker',
        title: '今天最大的阻碍是什么？',
        placeholder: '写下阻碍、卡点或让你分心的事情...',
        required: false,
        maxLength: 500,
        sortOrder: 2,
      ),
      ReviewQuestion(
        id: 'custom-next',
        title: '明天先做哪一步？',
        placeholder: '给明天留一个可以直接开始的第一步...',
        required: true,
        maxLength: 500,
        sortOrder: 3,
      ),
    ],
  ),
];

/// 默认 store：激活官方方案。
final ReviewSchemeStore defaultSchemeStore = ReviewSchemeStore(
  activeSchemeId: officialSchemeId,
  schemes: defaultSchemes,
);

final RegExp _jsonBlockRe = RegExp(r'```json\s*([\s\S]*?)```');

/// 从 scheme.md 提取 JSON 并解析；格式异常回退默认方案。
ReviewSchemeStore parseSchemeDoc(String md) {
  if (md.trim().isEmpty) return cloneDefaultStore();
  final match = _jsonBlockRe.firstMatch(md);
  if (match == null) return cloneDefaultStore();
  final jsonStr = match.group(1)?.trim();
  if (jsonStr == null || jsonStr.isEmpty) return cloneDefaultStore();
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) return cloneDefaultStore();
    final activeId =
        (decoded['activeSchemeId'] ?? officialSchemeId).toString();
    final rawSchemes = decoded['schemes'];
    if (rawSchemes is! List || rawSchemes.isEmpty) {
      return cloneDefaultStore();
    }
    final schemes = rawSchemes
        .map((e) =>
            ReviewQuestionScheme.fromJson(e as Map<String, dynamic>))
        .toList();
    return ReviewSchemeStore(activeSchemeId: activeId, schemes: schemes);
  } catch (_) {
    return cloneDefaultStore();
  }
}

/// 序列化为 scheme.md（JSON-in-Markdown）。
String serializeSchemeDoc(ReviewSchemeStore store) {
  final json = jsonEncode({
    'activeSchemeId': store.activeSchemeId,
    'schemes': store.schemes.map((s) => s.toJson()).toList(),
  });
  return '''# LifeScale 复盘方案

> 本文件由 LifeScale 维护，存放复盘题目方案（官方 + 自定义）。请勿手动删除 json 代码块。

```json
$json
```
''';
}

ReviewSchemeStore cloneDefaultStore() => ReviewSchemeStore(
      activeSchemeId: defaultSchemeStore.activeSchemeId,
      schemes: defaultSchemeStore.schemes
          .map((s) => ReviewQuestionScheme(
                id: s.id,
                name: s.name,
                source: s.source,
                isDefault: s.isDefault,
                questions: s.questions
                    .map((q) => ReviewQuestion(
                          id: q.id,
                          title: q.title,
                          placeholder: q.placeholder,
                          required: q.required,
                          maxLength: q.maxLength,
                          sortOrder: q.sortOrder,
                        ))
                    .toList(),
              ))
          .toList(),
    );
