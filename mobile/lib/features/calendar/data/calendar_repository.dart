import '../../../shared/constants/markdown.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../daily_markdown/domain/daily_doc.dart';
import '../domain/calendar_models.dart';

/// 日历仓库：派生每月每天的标记状态（docs/09 P3 SQL 归档 + settled 驱动）。
///
/// 数据源为 **本地 SQLite**（lifescale.db 真相源）：
/// - 候选日期 = 当月 ls_daily_settlement 有沉淀记录的日期；
/// - 每天的状态（日程数/快记数/复盘）从 SQL 归档实体派生（readDaily 已切 SQL）。
///
/// 与桌面 useLocalCalendarMonth 的 deriveCalendarMonthFromSettlements 对齐。
class CalendarRepository {
  CalendarRepository(this._mutation);

  final DailyMutationService _mutation;

  /// 加载某月每天状态（settled 记录驱动）。
  Future<CalendarMonthData> loadMonth(int year, int month) async {
    final yearMonth = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final db = _mutation.lsDb;
    final settledDates = await db.listSettledDatesInMonth(yearMonth);

    final allDays = <String, CalendarDayStatus>{};
    for (final date in settledDates) {
      allDays[date] = await _deriveDayStatus(date);
    }

    return CalendarMonthData(
      year: year,
      month: month,
      days: allDays,
      weekdayHeaders: const ['一', '二', '三', '四', '五', '六', '日'],
    );
  }

  /// 解析单天详情（点击日期查看时）。从 SQL 归档实体派生。
  Future<CalendarDayStatus> loadDayDetail(String date) async {
    return _deriveDayStatus(date);
  }

  // ============================ 内部 ============================

  Future<CalendarDayStatus> _deriveDayStatus(String date) async {
    try {
      final read = await _mutation.readDaily(date);
      final model = read.model;
      final hasData = model.schedules.isNotEmpty ||
          model.quickNotes.isNotEmpty ||
          model.review.any((r) => r.content.trim().isNotEmpty) ||
          (model.focus != null && model.focus!.trim().isNotEmpty);
      if (!hasData) {
        return CalendarDayStatus(
          date: date,
          hasContent: false,
          scheduleCount: 0,
          completedCount: 0,
          quickNoteCount: 0,
          reviewDone: false,
        );
      }
      return _statusFromModel(date, model);
    } catch (_) {
      return CalendarDayStatus(
        date: date,
        hasContent: false,
        scheduleCount: 0,
        completedCount: 0,
        quickNoteCount: 0,
        reviewDone: false,
      );
    }
  }

  CalendarDayStatus _statusFromModel(String date, DailyDocModel model) {
    final tasks = model.schedules
        .where((s) => s.type != ScheduleType.note)
        .toList();
    final completed = tasks.where((t) => t.completed).length;
    final reviewDone = model.review.any((r) => r.content.trim().isNotEmpty);
    return CalendarDayStatus(
      date: date,
      hasContent: true,
      scheduleCount: tasks.length,
      completedCount: completed,
      quickNoteCount: model.quickNotes.length,
      reviewDone: reviewDone,
    );
  }
}
