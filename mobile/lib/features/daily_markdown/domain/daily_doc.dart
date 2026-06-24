import 'package:freezed_annotation/freezed_annotation.dart';

import 'quick_note.dart';
import 'schedule.dart';

part 'daily_doc.freezed.dart';

/// 复盘单条答案（题目 + 正文）。
@freezed
class ReviewEntry with _$ReviewEntry {
  const factory ReviewEntry({
    required String questionId,
    required String title,
    @Default('') String content,
  }) = _ReviewEntry;
}

/// 解析后的每日文档结构化模型。
@freezed
class DailyDocModel with _$DailyDocModel {
  const factory DailyDocModel({
    required String title,
    String? focus,
    @Default(<Schedule>[]) List<Schedule> schedules,
    @Default(<QuickNote>[]) List<QuickNote> quickNotes,
    @Default(<ReviewEntry>[]) List<ReviewEntry> review,
  }) = _DailyDocModel;
}

/// 解析结果。`dirty` 表示老文件缺 ID、解析时已补，需写回。
@freezed
class ParseResult with _$ParseResult {
  const factory ParseResult({
    required DailyDocModel model,
    @Default(false) bool dirty,
  }) = _ParseResult;
}
