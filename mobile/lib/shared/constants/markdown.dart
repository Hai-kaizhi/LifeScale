// Daily Markdown 文法常量（与桌面端 `desktop/src/services/vault/dailyDoc.ts` 1:1 对齐）。
//
// 行尾 HTML 注释嵌入稳定 ID；段标题固定；空段占位不带注释。

/// 段标题（不含 Markdown 前缀）。
class MarkdownSections {
  const MarkdownSections._();
  static const String focus = '## 今日重点';
  static const String schedule = '## 今日日程';
  static const String timeRecord = '### 时间记录';
  static const String quickNote = '## 快速记录';
  static const String review = '## 今日复盘';
}

/// 空段占位文案。
class MarkdownPlaceholders {
  const MarkdownPlaceholders._();
  static const String focus = '暂无今日重点。';
  static const String schedule = '暂无日程。';
  static const String quickNote = '暂无快速记录。';
  static const String review = '暂无复盘内容。';
  static const String reviewEmptyAnswer = '暂无。';
}

/// 日程类别（生活/工作）与对应展示色，键值与桌面端 `SCHEDULE_CATEGORY_COLORS` 一致。
enum ScheduleCategory {
  life('生活', '#22c55e'),
  work('工作', '#3b82f6');

  final String label;
  final String color;
  const ScheduleCategory(this.label, this.color);

  /// 由中文字符串还原类别；非「工作」一律归为「生活」（对齐桌面 `normalizeCategory`）。
  static ScheduleCategory fromLabel(String raw) => raw == '工作' ? work : life;
}

/// 日程类型：task=任务日程，note=时间记录。
enum ScheduleType { task, note }
