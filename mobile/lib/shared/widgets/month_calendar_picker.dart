import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/date_util.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/domain/calendar_models.dart';
import '../../features/daily_markdown/data/daily_mutation_service.dart';
import '../../features/phase1/presentation/phase1_theme.dart';

/// 自绘月历弹层：底部弹出，7 列网格，每格日期 + 标记点（任务/快记/复盘），
/// 支持翻月、点击日期选择。与回看页视觉一致。
///
/// 用法：`showMonthCalendarPicker(context, tokens, initialDate, onPicked)`。
Future<void> showMonthCalendarPicker(
  BuildContext context,
  Phase1ToneTokens tokens, {
  required DateTime initialDate,
  required ValueChanged<DateTime> onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.isDark ? const Color(0xFF11102A) : tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _MonthCalendarPicker(
      tokens: tokens,
      initialDate: initialDate,
      onPicked: (d) {
        Navigator.of(ctx).pop();
        onPicked(d);
      },
    ),
  );
}

class _MonthCalendarPicker extends ConsumerStatefulWidget {
  const _MonthCalendarPicker({
    required this.tokens,
    required this.initialDate,
    required this.onPicked,
  });

  final Phase1ToneTokens tokens;
  final DateTime initialDate;
  final ValueChanged<DateTime> onPicked;

  @override
  ConsumerState<_MonthCalendarPicker> createState() =>
      _MonthCalendarPickerState();
}

class _MonthCalendarPickerState extends ConsumerState<_MonthCalendarPicker> {
  late int _year;
  late int _month;
  CalendarMonthData? _monthData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = CalendarRepository(
      ref.read(dailyMutationServiceProvider),
    );
    try {
      final data = await repo.loadMonth(_year, _month);
      if (mounted) {
        setState(() {
          _monthData = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _year -= 1;
        _month = 12;
      } else {
        _month -= 1;
      }
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final isCurrentOrFuture =
        _year > now.year || (_year == now.year && _month >= now.month);
    if (isCurrentOrFuture) return;
    setState(() {
      if (_month == 12) {
        _year += 1;
        _month = 1;
      } else {
        _month += 1;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final layout = MonthLayout(_year, _month);
    final today = DateUtil.todayIso();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题 + 翻月
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: tokens.text,
                  onPressed: _prevMonth,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_year年$_month月',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: tokens.text,
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 周标题
            Row(
              children: ['一', '二', '三', '四', '五', '六', '日']
                  .map((h) => Expanded(
                        child: Center(
                          child: Text(h,
                              style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                    color: tokens.primary, strokeWidth: 2),
              )
            else
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 2,
                childAspectRatio: 0.95,
                children: _buildCells(layout, today, tokens),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCells(
      MonthLayout layout, String today, Phase1ToneTokens tokens) {
    final cells = <Widget>[];
    final selectedIso = DateUtil.iso(widget.initialDate);
    for (var i = 0; i < layout.gridCells; i++) {
      final dayOffset = i - layout.firstWeekdayIndex;
      final inMonth = dayOffset >= 0 && dayOffset < layout.daysInMonth;
      if (!inMonth) {
        cells.add(const SizedBox.shrink());
        continue;
      }
      final date = DateUtil.iso(DateTime(_year, _month, dayOffset + 1));
      final status = _monthData?.days[date];
      final isToday = date == today;
      final isSelected = date == selectedIso;
      final isFuture = date.compareTo(today) > 0;
      cells.add(GestureDetector(
        onTap: isFuture
            ? null
            : () => widget.onPicked(DateTime(_year, _month, dayOffset + 1)),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.primary.withValues(alpha: 0.18)
                : (status?.hasMarker == true
                    ? tokens.primary.withValues(alpha: 0.06)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? tokens.primary
                  : (isToday
                      ? tokens.primary.withValues(alpha: 0.5)
                      : Colors.transparent),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dayOffset + 1}',
                style: TextStyle(
                  color: isFuture
                      ? tokens.muted.withValues(alpha: 0.35)
                      : (isToday || isSelected ? tokens.primary : tokens.text),
                  fontSize: 14,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w900
                      : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              if (status?.hasMarker == true)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((status?.scheduleCount ?? 0) > 0)
                      _dot(tokens.primary),
                    if ((status?.quickNoteCount ?? 0) > 0)
                      Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: _dot(tokens.success)),
                    if (status?.reviewDone == true)
                      Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: _dot(tokens.primary)),
                  ],
                ),
            ],
          ),
        ),
      ));
    }
    return cells;
  }

  Widget _dot(Color color) => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
