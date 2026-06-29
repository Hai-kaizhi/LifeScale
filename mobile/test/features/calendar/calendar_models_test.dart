import 'package:flutter_test/flutter_test.dart';
import 'package:lifescale_mobile/features/calendar/domain/calendar_models.dart';

/// 日历纯逻辑测试：月份网格布局 + 日期状态派生 + 过去日期判断。
void main() {
  group('MonthLayout', () {
    test('2026年6月：30 天，1 号是周一（首列偏移 0）', () {
      final layout = MonthLayout(2026, 6);
      expect(layout.daysInMonth, 30);
      // 2026-06-01 是周一 → DateTime.weekday=1 → 偏移 0。
      expect(layout.firstWeekdayIndex, 0);
      expect(layout.gridCells, greaterThanOrEqualTo(30));
      expect(layout.gridCells % 7, 0); // 整周
      expect(layout.monthLabel, '2026年6月');
    });

    test('2026年2月：28 天（非闰年），首列偏移按实际周几', () {
      final layout = MonthLayout(2026, 2);
      expect(layout.daysInMonth, 28);
      expect(layout.gridCells % 7, 0);
    });

    test('2024年2月：29 天（闰年）', () {
      expect(MonthLayout(2024, 2).daysInMonth, 29);
    });

    test('12 月有 31 天', () {
      expect(MonthLayout(2026, 12).daysInMonth, 31);
    });
  });

  group('CalendarDayStatus', () {
    test('有内容 + 任务 + 复盘 → hasMarker 为 true，进度正确', () {
      const s = CalendarDayStatus(
        date: '2026-06-17',
        hasContent: true,
        scheduleCount: 4,
        completedCount: 3,
        quickNoteCount: 2,
        reviewDone: true,
      );
      expect(s.hasMarker, isTrue);
      expect(s.progress, closeTo(0.75, 1e-9));
      expect(s.summary, contains('3/4 任务'));
      expect(s.summary, contains('2 条记录'));
      expect(s.summary, contains('已复盘'));
    });

    test('无内容 → hasMarker false，summary 提示空', () {
      const s = CalendarDayStatus(
        date: '2026-06-18',
        hasContent: false,
        scheduleCount: 0,
        completedCount: 0,
        quickNoteCount: 0,
        reviewDone: false,
      );
      expect(s.hasMarker, isFalse);
      expect(s.progress, 0);
      expect(s.summary, contains('还没有 Daily'));
    });

    test('有 Daily 但无任务/快记/复盘 → hasMarker false', () {
      const s = CalendarDayStatus(
        date: '2026-06-19',
        hasContent: true,
        scheduleCount: 0,
        completedCount: 0,
        quickNoteCount: 0,
        reviewDone: false,
      );
      expect(s.hasMarker, isFalse);
    });
  });

  group('isDateOnOrBeforeToday', () {
    test('今天及过去返回 true，未来返回 false', () {
      // 用固定参照避免跨日 flaky：取今天、昨天、明天。
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      expect(isDateOnOrBeforeToday(today), isTrue);
      expect(isDateOnOrBeforeToday(iso(yesterday)), isTrue);
      expect(isDateOnOrBeforeToday(iso(tomorrow)), isFalse);
    });
  });

  group('CalendarMonthData', () {
    test('title 格式正确', () {
      const data = CalendarMonthData(
        year: 2026,
        month: 6,
        days: {},
        weekdayHeaders: ['一', '二', '三', '四', '五', '六', '日'],
      );
      expect(data.title, '2026年6月');
    });
  });
}
