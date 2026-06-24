import '../domain/daily_doc.dart';

/// 构造空白每日文档模型（标题由调用方按「YYYY年M月D日 周X」格式传入）。
class DailyDocFactory {
  DailyDocFactory._();

  static DailyDocModel createEmpty(String title) => DailyDocModel(
    title: title,
    focus: null,
    schedules: const [],
    quickNotes: const [],
    review: const [],
  );
}
