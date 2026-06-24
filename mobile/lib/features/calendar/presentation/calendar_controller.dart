import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../daily_markdown/data/daily_mutation_service.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_models.dart';

/// 日历页控制器：月份切换 + 日期选中 + 加载。
class CalendarController extends Notifier<CalendarState> {
  late int _year;
  late int _month;

  @override
  CalendarState build() {
    final ym = currentYearMonth();
    _year = ym.year;
    _month = ym.month;
    Future<void>.microtask(loadCurrentMonth);
    return const CalendarState();
  }

  int get year => _year;
  int get month => _month;

  Future<void> loadCurrentMonth() async {
    state = state.copyWith(status: CalendarLoadStatus.loading, clearMessage: true);
    try {
      final data = await ref
          .read(calendarRepositoryProvider)
          .loadMonth(_year, _month);
      state = state.copyWith(
        status: CalendarLoadStatus.ready,
        monthData: data,
      );
    } catch (e) {
      state = state.copyWith(
        status: CalendarLoadStatus.error,
        message: '日历加载失败：$e',
      );
    }
  }

  /// 选中某天（点击网格）。自动派生当天详情（已由 loadMonth 解析，直接取）。
  void selectDay(String date) {
    state = state.copyWith(selectedDate: date, clearMessage: true);
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedDate: true);
  }

  /// 上个月。
  Future<void> prevMonth() async {
    if (_month == 1) {
      _year -= 1;
      _month = 12;
    } else {
      _month -= 1;
    }
    await loadCurrentMonth();
  }

  /// 下个月（不超过当月）。
  Future<void> nextMonth() async {
    final now = DateTime.now();
    final isCurrentOrFuture = _year > now.year ||
        (_year == now.year && _month >= now.month);
    if (isCurrentOrFuture) {
      state = state.copyWith(message: '已经是最近月份');
      return;
    }
    if (_month == 12) {
      _year += 1;
      _month = 1;
    } else {
      _month += 1;
    }
    await loadCurrentMonth();
  }

  /// 跳转到指定年月（用于月份选择器）。
  Future<void> goToMonth(int year, int month) async {
    _year = year;
    _month = month;
    await loadCurrentMonth();
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(
    ref.watch(dailyMutationServiceProvider),
  ),
);

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

/// 选中日期的当天状态（供摘要卡片展示）。
final selectedDayStatusProvider = Provider<CalendarDayStatus?>((ref) {
  final state = ref.watch(calendarControllerProvider);
  final selected = state.selectedDate;
  if (selected == null || state.monthData == null) return null;
  return state.monthData!.days[selected];
});
