import '../../../core/util/id_util.dart';
import '../../../shared/constants/markdown.dart';
import '../domain/daily_doc.dart';
import '../domain/quick_note.dart';
import '../domain/schedule.dart';

/// Daily Markdown 解析器（1:1 移植 `desktop/src/services/vault/dailyDoc.ts#parseDailyDoc`）。
///
/// 行尾 HTML 注释嵌入稳定 ID，保证可往返。老文件（无 ID）解析时自动补 ID 并标记 dirty。
class DailyDocParser {
  DailyDocParser._();

  static final RegExp _commentRe = RegExp(
    r'\s*<!--\s*([a-zA-Z]+)(?::([0-9A-Za-z_-]+))?\s*-->\s*$',
  );
  static final RegExp _taskHeadRe = RegExp(r'^- \[([xX ])\] (.+)$');
  static final RegExp _bulletRe = RegExp(r'^- (.+)$');
  // 注意末尾为中文括号「（）」。
  static final RegExp _rangeRe = RegExp(
    r'^(\d{1,2}:\d{2})-(\d{1,2}:\d{2}) (.+)（([^）]+)）$',
  );
  static final RegExp _quickRe = RegExp(r'^(\d{1,2}:\d{2}) (.+)$');

  /// 解析 Daily Markdown。`date` 用于补全 schedule.date 与 quickNote.createdAt。
  static ParseResult parse(String md, {String date = ''}) {
    final lines = md.split(RegExp(r'\r?\n'));

    var title = '';
    String? focus;
    final schedules = <Schedule>[];
    final quickNotes = <QuickNote>[];
    final review = <ReviewEntry>[];
    final focusScheduleIds = <String>[];

    var section = _Section.none;
    ReviewEntry? currentReview;
    var dirty = false;
    var order = 0;

    String assignId() {
      dirty = true;
      return IdUtil.newId();
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        title = trimmed.substring(2).trim();
        continue;
      }
      if (trimmed == MarkdownSections.focus) {
        section = _Section.focus;
        continue;
      }
      if (trimmed == MarkdownSections.schedule) {
        section = _Section.schedule;
        continue;
      }
      if (trimmed == MarkdownSections.quickNote) {
        section = _Section.quickNote;
        continue;
      }
      if (trimmed == MarkdownSections.review) {
        if (currentReview != null) review.add(currentReview);
        currentReview = null;
        section = _Section.review;
        continue;
      }
      if (trimmed == MarkdownSections.timeRecord &&
          section == _Section.schedule) {
        section = _Section.note;
        continue;
      }
      if (trimmed.startsWith('### ') && section == _Section.review) {
        if (currentReview != null) review.add(currentReview);
        final c = _parseComment(trimmed);
        final reviewTitle = c.body.replaceFirst(RegExp(r'^###\s+'), '').trim();
        String questionId;
        if (c.key == 'rv' && c.id != null) {
          questionId = c.id!;
        } else {
          questionId = c.id ?? assignId();
          dirty = true;
        }
        currentReview = ReviewEntry(
          questionId: questionId,
          title: reviewTitle,
          content: '',
        );
        continue;
      }

      switch (section) {
        case _Section.focus:
          if (!RegExp(r'^- ').hasMatch(trimmed)) continue; // 占位行忽略
          final c = _parseComment(trimmed);
          final text = c.body.replaceFirst(RegExp(r'^-\s+'), '').trim();
          if (c.key == 'focus') {
            focus = text;
          } else if (c.key == 'sid' && c.id != null) {
            focusScheduleIds.add(c.id!);
          } else if (focus == null && text.isNotEmpty) {
            // 无注释旧行：兼容当自由重点
            focus = text;
          }
          continue;
        case _Section.schedule:
          final sch = _parseScheduleLine(
            trimmed,
            ScheduleType.task,
            date,
            order,
            assignId,
          );
          if (sch != null) {
            schedules.add(sch);
            order += 1;
          }
          continue;
        case _Section.note:
          final sch = _parseScheduleLine(
            trimmed,
            ScheduleType.note,
            date,
            order,
            assignId,
          );
          if (sch != null) {
            schedules.add(sch);
            order += 1;
          }
          continue;
        case _Section.quickNote:
          final qn = _parseQuickNoteLine(trimmed, date, assignId);
          if (qn != null) quickNotes.add(qn);
          continue;
        case _Section.review:
          // 缩进行 → 当前问题答案（容错：任意前导空白）
          if (currentReview != null && RegExp(r'^\s+\S').hasMatch(rawLine)) {
            final lineText = rawLine.trim();
            if (lineText.isNotEmpty &&
                lineText != MarkdownPlaceholders.reviewEmptyAnswer) {
              currentReview = currentReview.copyWith(
                content: currentReview.content.isEmpty
                    ? lineText
                    : '${currentReview.content}\n$lineText',
              );
            }
          }
          continue;
        case _Section.none:
          continue;
      }
    }
    if (currentReview != null) review.add(currentReview);

    // 应用重点引用 → schedule.focus
    final focusSet = focusScheduleIds.toSet();
    if (focusSet.isNotEmpty) {
      for (var i = 0; i < schedules.length; i++) {
        if (focusSet.contains(schedules[i].id)) {
          schedules[i] = schedules[i].copyWith(focus: true);
        }
      }
    }

    return ParseResult(
      model: DailyDocModel(
        title: title,
        focus: focus,
        schedules: schedules,
        quickNotes: quickNotes,
        review: review,
      ),
      dirty: dirty,
    );
  }

  static _ParsedComment _parseComment(String line) {
    final m = _commentRe.firstMatch(line);
    if (m == null) return _ParsedComment(line, null, null);
    final body = line.substring(0, m.start).trimRight();
    return _ParsedComment(body, m.group(1)!.toLowerCase(), m.group(2));
  }

  static Schedule? _parseScheduleLine(
    String line,
    ScheduleType type,
    String date,
    int order,
    String Function() assignId,
  ) {
    final c = _parseComment(line);
    late String rest;
    String? mark;
    if (type == ScheduleType.task) {
      final tm = _taskHeadRe.firstMatch(c.body);
      if (tm == null) return null;
      mark = tm.group(1);
      rest = tm.group(2)!;
    } else {
      final nm = _bulletRe.firstMatch(c.body);
      if (nm == null) return null;
      rest = nm.group(1)!;
    }
    final rm = _rangeRe.firstMatch(rest);
    if (rm == null) return null;
    final start = rm.group(1)!;
    final end = rm.group(2)!;
    final title = rm.group(3)!;
    final categoryRaw = rm.group(4)!;
    final sid = (c.key == 'sid' && c.id != null) ? c.id! : assignId();
    final category = ScheduleCategory.fromLabel(categoryRaw);
    return Schedule(
      id: sid,
      title: title.trim(),
      completed: type == ScheduleType.task
          ? (mark != null && mark.toLowerCase() == 'x')
          : false,
      category: category,
      categoryColor: category.color,
      type: type,
      startTime: start,
      endTime: end,
      date: date,
      sortOrder: order,
    );
  }

  static QuickNote? _parseQuickNoteLine(
    String line,
    String date,
    String Function() assignId,
  ) {
    final c = _parseComment(line);
    final m = _bulletRe.firstMatch(c.body);
    if (m == null) return null;
    final qm = _quickRe.firstMatch(m.group(1)!);
    if (qm == null) return null;
    final time = qm.group(1)!;
    final content = qm.group(2)!;
    final qnId = (c.key == 'qn' && c.id != null) ? c.id! : assignId();
    final createdAt = '${date}T$time:00.000';
    return QuickNote(
      id: qnId,
      date: date,
      content: content.trim(),
      sourceDevice: 'desktop',
      status: 'active',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  /// 解析「纯净」Daily Markdown（docs/09 §12.1 沉淀文法产物，回看 P3 用）。
  ///
  /// 与 [parse] 的核心差异：纯净文法**无行尾注释**，实体无稳定 ID。
  /// 解析时实体 ID 用临时分配（不落库），dirty 恒 false。
  /// 重点↔日程关联靠内容指纹（同时间段+同标题）推断。
  /// 与桌面 parseCleanMd 对齐。
  static ParseResult parseClean(String md, {String date = ''}) {
    final lines = md.split(RegExp(r'\r?\n'));

    var title = '';
    String? focus;
    final schedules = <Schedule>[];
    final quickNotes = <QuickNote>[];
    final review = <ReviewEntry>[];
    final focusRefs = <_FocusRef>[];

    var section = _Section.none;
    ReviewEntry? currentReview;
    var order = 0;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        title = trimmed.substring(2).trim();
        continue;
      }
      if (trimmed == MarkdownSections.focus) {
        section = _Section.focus;
        continue;
      }
      if (trimmed == MarkdownSections.schedule) {
        section = _Section.schedule;
        continue;
      }
      if (trimmed == MarkdownSections.quickNote) {
        section = _Section.quickNote;
        continue;
      }
      if (trimmed == MarkdownSections.review) {
        if (currentReview != null) review.add(currentReview);
        currentReview = null;
        section = _Section.review;
        continue;
      }
      if (trimmed == MarkdownSections.timeRecord && section == _Section.schedule) {
        section = _Section.note;
        continue;
      }
      if (trimmed.startsWith('### ') && section == _Section.review) {
        if (currentReview != null) review.add(currentReview);
        currentReview = ReviewEntry(
          questionId: IdUtil.newId(),
          title: trimmed.substring(4).trim(),
          content: '',
        );
        continue;
      }

      switch (section) {
        case _Section.focus:
          if (!trimmed.startsWith('- ')) continue;
          final text = trimmed.substring(2).trim();
          // 尝试匹配「HH:MM-HH:MM 标题」（日程重点引用）。
          final refMatch = RegExp(r'^(\d{1,2}:\d{2})-(\d{1,2}:\d{2}) (.+)$').firstMatch(text);
          if (refMatch != null) {
            focusRefs.add(_FocusRef(refMatch.group(1)!, refMatch.group(2)!, refMatch.group(3)!.trim()));
          } else if (focus == null) {
            focus = text;
          }
          continue;
        case _Section.schedule:
          final sch = _parseCleanScheduleLine(trimmed, ScheduleType.task, date, order);
          if (sch != null) {
            schedules.add(sch);
            order++;
          }
          continue;
        case _Section.note:
          final sch = _parseCleanScheduleLine(trimmed, ScheduleType.note, date, order);
          if (sch != null) {
            schedules.add(sch);
            order++;
          }
          continue;
        case _Section.quickNote:
          final qn = _parseCleanQuickNoteLine(trimmed, date);
          if (qn != null) quickNotes.add(qn);
          continue;
        case _Section.review:
          if (currentReview != null && RegExp(r'^\s+\S').hasMatch(rawLine)) {
            final lineText = rawLine.trim();
            if (lineText.isNotEmpty && lineText != MarkdownPlaceholders.reviewEmptyAnswer) {
              currentReview = currentReview.copyWith(
                content: currentReview.content.isEmpty ? lineText : '${currentReview.content}\n$lineText',
              );
            }
          }
          continue;
        default:
          continue;
      }
    }
    if (currentReview != null) review.add(currentReview);

    // 内容指纹匹配：重点引用命中日程 → 置 focus。
    for (final ref in focusRefs) {
      final idx = schedules.indexWhere(
        (s) => s.startTime == ref.start && s.endTime == ref.end && s.title == ref.title,
      );
      if (idx >= 0) {
        schedules[idx] = schedules[idx].copyWith(focus: true);
      }
    }

    return ParseResult(
      model: DailyDocModel(
        title: title,
        focus: focus,
        schedules: schedules,
        quickNotes: quickNotes,
        review: review,
      ),
      dirty: false,
    );
  }

  /// 解析纯净日程行（无注释，ID 临时分配）。
  static Schedule? _parseCleanScheduleLine(
    String line,
    ScheduleType type,
    String date,
    int order,
  ) {
    String rest;
    String? mark;
    if (type == ScheduleType.task) {
      final tm = _taskHeadRe.firstMatch(line);
      if (tm == null) return null;
      mark = tm.group(1);
      rest = tm.group(2)!;
    } else {
      final nm = _bulletRe.firstMatch(line);
      if (nm == null) return null;
      rest = nm.group(1)!;
    }
    final rm = _rangeRe.firstMatch(rest);
    if (rm == null) return null;
    final category = ScheduleCategory.fromLabel(rm.group(4)!);
    return Schedule(
      id: IdUtil.newId(),
      title: rm.group(3)!.trim(),
      completed: type == ScheduleType.task ? (mark != null && mark.toLowerCase() == 'x') : false,
      category: category,
      categoryColor: category.color,
      type: type,
      startTime: rm.group(1)!,
      endTime: rm.group(2)!,
      date: date,
      sortOrder: order,
    );
  }

  /// 解析纯净快速记录行（无注释，ID 临时分配）。
  static QuickNote? _parseCleanQuickNoteLine(String line, String date) {
    final m = _bulletRe.firstMatch(line);
    if (m == null) return null;
    final qm = _quickRe.firstMatch(m.group(1)!);
    if (qm == null) return null;
    final time = qm.group(1)!;
    final content = qm.group(2)!;
    final createdAt = '${date}T$time:00.000';
    return QuickNote(
      id: IdUtil.newId(),
      date: date,
      content: content.trim(),
      sourceDevice: 'mobile',
      status: 'active',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }
}

/// 重点段日程引用（内容指纹用）。
class _FocusRef {
  const _FocusRef(this.start, this.end, this.title);
  final String start;
  final String end;
  final String title;
}

enum _Section { none, focus, schedule, note, quickNote, review }

class _ParsedComment {
  const _ParsedComment(this.body, this.key, this.id);
  final String body;
  final String? key;
  final String? id;
}
