import '../../../core/util/date_util.dart';

/// 单日的日历标记状态（由对应日期的 Daily Markdown 派生）。
class CalendarDayStatus {
  const CalendarDayStatus({
    required this.date,
    required this.hasContent,
    required this.scheduleCount,
    required this.completedCount,
    required this.quickNoteCount,
    required this.reviewDone,
  });

  final String date; // YYYY-MM-DD
  final bool hasContent; // 当天有 Daily 文件
  final int scheduleCount; // 日程（task）总数
  final int completedCount; // 已完成数
  final int quickNoteCount; // 快速记录数
  final bool reviewDone; // 复盘已填写

  /// 完成进度（0~1）。
  double get progress =>
      scheduleCount == 0 ? 0 : completedCount / scheduleCount;

  /// 是否值得在日历上显示标记（有任意内容）。
  bool get hasMarker =>
      hasContent &&
      (scheduleCount > 0 || quickNoteCount > 0 || reviewDone);

  /// 简短摘要（点击当天查看时的副标题）。
  String get summary {
    if (!hasContent) return '这一天还没有 Daily 内容';
    final parts = <String>[];
    if (scheduleCount > 0) {
      parts.add('$completedCount/$scheduleCount 任务');
    }
    if (quickNoteCount > 0) {
      parts.add('$quickNoteCount 条记录');
    }
    parts.add(reviewDone ? '已复盘' : '未复盘');
    return parts.join(' · ');
  }

  static const CalendarDayStatus empty = CalendarDayStatus(
    date: '',
    hasContent: false,
    scheduleCount: 0,
    completedCount: 0,
    quickNoteCount: 0,
    reviewDone: false,
  );

  CalendarDayStatus copyWith({
    String? date,
    bool? hasContent,
    int? scheduleCount,
    int? completedCount,
    int? quickNoteCount,
    bool? reviewDone,
  }) =>
      CalendarDayStatus(
        date: date ?? this.date,
        hasContent: hasContent ?? this.hasContent,
        scheduleCount: scheduleCount ?? this.scheduleCount,
        completedCount: completedCount ?? this.completedCount,
        quickNoteCount: quickNoteCount ?? this.quickNoteCount,
        reviewDone: reviewDone ?? this.reviewDone,
      );
}

/// 月历视图数据。
class CalendarMonthData {
  const CalendarMonthData({
    required this.year,
    required this.month, // 1-12
    required this.days, // 该月每天状态，key=YYYY-MM-DD
    required this.weekdayHeaders, // 周标题 ['一',...,'日']
  });

  final int year;
  final int month;
  final Map<String, CalendarDayStatus> days;
  final List<String> weekdayHeaders;

  /// 该月标题，如「2026年6月」。
  String get title => '$year年$month月';
}

/// 日历加载状态。
enum CalendarLoadStatus { loading, ready, error }

class CalendarState {
  const CalendarState({
    this.status = CalendarLoadStatus.loading,
    this.monthData,
    this.selectedDate,
    this.message,
  });

  final CalendarLoadStatus status;
  final CalendarMonthData? monthData;
  final String? selectedDate; // 选中的日期（YYYY-MM-DD），点击后用于查看当天
  final String? message;

  CalendarState copyWith({
    CalendarLoadStatus? status,
    CalendarMonthData? monthData,
    bool clearMonthData = false,
    String? selectedDate,
    bool clearSelectedDate = false,
    String? message,
    bool clearMessage = false,
  }) =>
      CalendarState(
        status: status ?? this.status,
        monthData: clearMonthData ? null : monthData ?? this.monthData,
        selectedDate:
            clearSelectedDate ? null : selectedDate ?? this.selectedDate,
        message: clearMessage ? null : message ?? this.message,
      );
}

/// 计算某月共多少天、首日是周几（周一=0），用于月历网格布局。
class MonthLayout {
  MonthLayout(int year, int month)
      : daysInMonth = _daysInMonth(year, month),
        // DateTime.weekday：周一=1..周日=7，转为周一=0 的索引。
        firstWeekdayIndex = (DateTime(year, month).weekday - 1) {
    firstOfMonth = DateTime(year, month);
    monthLabel = '$year年$month月';
  }

  final int daysInMonth;
  final int firstWeekdayIndex; // 该月 1 号在网格中的列偏移（0=周一）
  late final DateTime firstOfMonth;
  late final String monthLabel;

  /// 网格总格数（含上月末尾补位 + 本月 + 下月开头补位，向上取整到整周）。
  int get gridCells {
    final raw = firstWeekdayIndex + daysInMonth;
    return ((raw + 6) ~/ 7) * 7; // 向上取整到 7 的倍数
  }

  static int _daysInMonth(int year, int month) {
    // 下个月 0 号 = 本月最后一天。
    return DateTime(year, month + 1, 0).day;
  }
}

/// YYYY-MM-DD 是否在今天之前（含今天）。
bool isDateOnOrBeforeToday(String date) =>
    date.compareTo(DateUtil.todayIso()) <= 0;

/// 当前年月（用于初始展示）。
({int year, int month}) currentYearMonth() {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
}
