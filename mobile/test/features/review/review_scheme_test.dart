import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/features/review/data/review_scheme.dart';

/// 复盘方案解析测试：验证与桌面端 reviewScheme.ts 的契约一致性。
/// 关键不变量：official-* 题目 ID 永久稳定，保证历史 <!-- rv:questionId --> 可匹配。
void main() {
  group('parseSchemeDoc / serializeSchemeDoc', () {
    test('空文档 → 内置默认方案（official 4 题 + 轻量 3 题）', () {
      final store = parseSchemeDoc('');
      expect(store.activeSchemeId, officialSchemeId);
      expect(store.schemes, hasLength(2));
      final official = store.activeScheme;
      expect(official.source, 'official');
      expect(official.questions.map((q) => q.id), contains('official-done'));
      expect(official.questions.map((q) => q.id),
          contains('official-tomorrow'));
      expect(official.questions, hasLength(4));
    });

    test('异常 JSON → 回退默认方案，不抛异常', () {
      final store = parseSchemeDoc('```json\n{不是合法 json\n```');
      expect(store.activeSchemeId, officialSchemeId);
    });

    test('official 题目 ID 稳定（历史复盘可永久匹配）', () {
      final store = parseSchemeDoc('');
      final ids = store.activeScheme.questions.map((q) => q.id).toSet();
      expect(ids, containsAll(const [
        'official-done',
        'official-undone',
        'official-gain',
        'official-tomorrow',
      ]));
    });

    test('往返：serialize(parse(serialize(store))) 稳定', () {
      final store = parseSchemeDoc('');
      final md = serializeSchemeDoc(store);
      final reparsed = parseSchemeDoc(md);
      expect(reparsed.activeSchemeId, store.activeSchemeId);
      expect(reparsed.schemes, hasLength(store.schemes.length));
      // 题目 ID 序列完全保留。
      final before =
          store.activeScheme.questions.map((q) => q.id).toList();
      final after =
          reparsed.activeScheme.questions.map((q) => q.id).toList();
      expect(after, before);
    });

    test('自定义方案：解析出 activeSchemeId + 自定义题目', () {
      const md = '''# LifeScale 复盘方案

```json
{
  "activeSchemeId": "scheme-custom-light",
  "schemes": [
    {
      "id": "scheme-custom-light",
      "name": "我的轻量复盘",
      "source": "custom",
      "isDefault": false,
      "questions": [
        {"id": "custom-progress", "title": "今天最值得记录的进展？", "required": true, "maxLength": 500, "sortOrder": 1}
      ]
    }
  ]
}
```
''';
      final store = parseSchemeDoc(md);
      expect(store.activeSchemeId, 'scheme-custom-light');
      expect(store.activeScheme.questions.first.id, 'custom-progress');
    });
  });
}
