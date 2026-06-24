import '../../../shared/constants/markdown.dart';
import '../domain/daily_doc.dart';

/// Daily Markdown 序列化器（1:1 移植 `desktop/src/services/vault/dailyDoc.ts#serializeDailyDoc`）。
///
/// 带 ID、段间空行，Obsidian 友好；空段使用占位文案（不带注释）。
class DailyDocSerializer {
  DailyDocSerializer._();

  static final RegExp _timeInIsoRe = RegExp(r'T(\d{2}:\d{2})');

  static String serialize(DailyDocModel model) {
    final parts = <String>[];

    parts.add('# ${model.title}');
    parts.add('');

    // —— 今日重点 ——
    parts.add(MarkdownSections.focus);
    final focusLines = <String>[];
    if (model.focus != null && model.focus!.trim().isNotEmpty) {
      focusLines.add('- ${model.focus!.trim()} <!-- focus -->');
    }
    for (final s in model.schedules) {
      if (s.focus == true) {
        focusLines.add(
          '- ${s.startTime}-${s.endTime} ${s.title} <!-- sid:${s.id} -->',
        );
      }
    }
    parts.add(
      focusLines.isNotEmpty
          ? focusLines.join('\n')
          : MarkdownPlaceholders.focus,
    );

    // —— 今日日程 ——
    parts.add('');
    parts.add(MarkdownSections.schedule);
    final tasks = model.schedules
        .where((s) => s.type != ScheduleType.note)
        .toList();
    final notes = model.schedules
        .where((s) => s.type == ScheduleType.note)
        .toList();
    final taskLines = tasks
        .map(
          (s) =>
              '- [${s.completed ? 'x' : ' '}] ${s.startTime}-${s.endTime} ${s.title}（${s.category.label}） <!-- sid:${s.id} -->',
        )
        .toList();
    parts.add(
      taskLines.isNotEmpty
          ? taskLines.join('\n')
          : MarkdownPlaceholders.schedule,
    );
    if (notes.isNotEmpty) {
      parts.add(MarkdownSections.timeRecord);
      parts.add(
        notes
            .map(
              (s) =>
                  '- ${s.startTime}-${s.endTime} ${s.title}（${s.category.label}） <!-- sid:${s.id} -->',
            )
            .join('\n'),
      );
    }

    // —— 快速记录 ——
    parts.add('');
    parts.add(MarkdownSections.quickNote);
    final qnLines = model.quickNotes
        .map(
          (q) =>
              '- ${_quickNoteTime(q.createdAt)} ${q.content} <!-- qn:${q.id} -->',
        )
        .toList();
    parts.add(
      qnLines.isNotEmpty ? qnLines.join('\n') : MarkdownPlaceholders.quickNote,
    );

    // —— 今日复盘 ——
    parts.add('');
    parts.add(MarkdownSections.review);
    if (model.review.isNotEmpty) {
      parts.add(
        model.review
            .map((r) {
              final head = '### ${r.title} <!-- rv:${r.questionId} -->';
              final body = r.content.trim().isNotEmpty
                  ? _indentMultiline(r.content)
                  : MarkdownPlaceholders.reviewEmptyAnswer;
              return '$head\n$body';
            })
            .join('\n\n'),
      );
    } else {
      parts.add(MarkdownPlaceholders.review);
    }

    return parts.join('\n');
  }

  /// 从 createdAt（ISO 或 YYYY-MM-DDTHH:mm:...）取 HH:mm。
  static String _quickNoteTime(String createdAt) {
    final m = _timeInIsoRe.firstMatch(createdAt);
    return m == null ? '00:00' : m.group(1)!;
  }

  static String _indentMultiline(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '  $line')
        .join('\n');
  }

  /// 序列化「纯净」Daily Markdown（docs/09 §12.1 沉淀文法）：**零 `<!-- -->` 程序标记**，
  /// 标准 Markdown，兼容 AI 直读与 Obsidian。结构段序、占位文案与 [serialize] 一致，
  /// 仅去掉所有行尾稳定 ID 注释。沉淀动作的输出产物（与桌面 serializeCleanDailyDoc 对齐）。
  static String serializeClean(DailyDocModel model) {
    final parts = <String>[];

    parts.add('# ${model.title}');
    parts.add('');

    // —— 今日重点 ——
    parts.add(MarkdownSections.focus);
    final focusLines = <String>[];
    if (model.focus != null && model.focus!.trim().isNotEmpty) {
      focusLines.add('- ${model.focus!.trim()}');
    }
    for (final s in model.schedules) {
      if (s.focus == true) {
        focusLines.add('- ${s.startTime}-${s.endTime} ${s.title}');
      }
    }
    parts.add(
      focusLines.isNotEmpty ? focusLines.join('\n') : MarkdownPlaceholders.focus,
    );

    // —— 今日日程 ——
    parts.add('');
    parts.add(MarkdownSections.schedule);
    final tasks = model.schedules
        .where((s) => s.type != ScheduleType.note)
        .toList();
    final notes = model.schedules
        .where((s) => s.type == ScheduleType.note)
        .toList();
    final taskLines = tasks
        .map(
          (s) =>
              '- [${s.completed ? 'x' : ' '}] ${s.startTime}-${s.endTime} ${s.title}（${s.category.label}）',
        )
        .toList();
    parts.add(
      taskLines.isNotEmpty
          ? taskLines.join('\n')
          : MarkdownPlaceholders.schedule,
    );
    if (notes.isNotEmpty) {
      parts.add(MarkdownSections.timeRecord);
      parts.add(
        notes
            .map(
              (s) =>
                  '- ${s.startTime}-${s.endTime} ${s.title}（${s.category.label}）',
            )
            .join('\n'),
      );
    }

    // —— 快速记录 ——
    parts.add('');
    parts.add(MarkdownSections.quickNote);
    final qnLines = model.quickNotes
        .map((q) => '- ${_quickNoteTime(q.createdAt)} ${q.content}')
        .toList();
    parts.add(
      qnLines.isNotEmpty ? qnLines.join('\n') : MarkdownPlaceholders.quickNote,
    );

    // —— 今日复盘 ——
    parts.add('');
    parts.add(MarkdownSections.review);
    if (model.review.isNotEmpty) {
      parts.add(
        model.review
            .map((r) {
              final head = '### ${r.title}';
              final body = r.content.trim().isNotEmpty
                  ? _indentMultiline(r.content)
                  : MarkdownPlaceholders.reviewEmptyAnswer;
              return '$head\n$body';
            })
            .join('\n\n'),
      );
    } else {
      parts.add(MarkdownPlaceholders.review);
    }

    return parts.join('\n');
  }
}
