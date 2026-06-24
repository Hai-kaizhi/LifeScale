import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/util/date_util.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';
import '../../today/presentation/today_page.dart' show showCreateActionSheet;
import '../domain/calendar_models.dart';
import 'calendar_controller.dart';

/// 日历回看页：月历网格 + 日期标记 + 选中当天摘要 + 查看当天入口。
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    // 时段色调跟随全局 ThemeController（不再写死 night）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    final selected = ref.watch(selectedDayStatusProvider);

    // 监听 AppShell 中央「+」创建信号：在当前页（不跳转）针对选中日弹出创建菜单。
    // 选中日已由 AppShell._onCreate 写入 TodayController.selectedDate，
    // 因此 showCreateActionSheet 的所有写入都作用于该日。
    ref.listen<int>(
      calendarCreateSignalProvider.select((n) => n.value),
      (_, value) {
        if (value == 0) return;
        showCreateActionSheet(context, ref, tokens);
      },
    );

    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 顶部：标题 + 月份切换（tab 式页面，无返回箭头）。
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: tokens.text,
                    onPressed: controller.prevMonth,
                  ),
                  GestureDetector(
                    onTap: () => _pickMonth(context, controller, tokens),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        state.monthData?.title ??
                            '${controller.year}年${controller.month}月',
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: tokens.text,
                    onPressed: controller.nextMonth,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    color: tokens.text,
                    onPressed: controller.loadCurrentMonth,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
              child: _body(state, controller, tokens, selected, context, ref)),
        ],
      ),
    );

  }

  Widget _body(
    CalendarState state,
    CalendarController controller,
    Phase1ToneTokens tokens,
    CalendarDayStatus? selected,
    BuildContext context,
    WidgetRef ref,
  ) {
    switch (state.status) {
      case CalendarLoadStatus.loading:
        return Center(
          child: CircularProgressIndicator(color: tokens.primary),
        );
      case CalendarLoadStatus.error:
        return _Message(
          tokens: tokens,
          icon: Icons.error_outline,
          text: state.message ?? '日历加载失败',
          action: '重试',
          onAction: controller.loadCurrentMonth,
        );
      case CalendarLoadStatus.ready:
        final month = state.monthData;
        if (month == null) {
          return _Message(
            tokens: tokens,
            icon: Icons.calendar_month_outlined,
            text: '本月暂无记录',
          );
        }
        // 月历网格 + 当天详情放入同一个滚动容器，整页一起滚动
        // （此前详情卡片内部独立滚动、月历不动，体验割裂）。
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            children: [
              _MonthGrid(
                month: month,
                tokens: tokens,
                selectedDate: state.selectedDate,
                onTap: controller.selectDay,
              ),
              const SizedBox(height: 4),
              if (selected != null && state.selectedDate != null)
                _DayDetail(
                  date: state.selectedDate!,
                  status: selected,
                  tokens: tokens,
                )
              else
                _Message(
                  tokens: tokens,
                  icon: Icons.touch_app_outlined,
                  text: '点击某个日期查看当天详情',
                ),
            ],
          ),
        );
    }
  }

  Future<void> _pickMonth(
    BuildContext context,
    CalendarController controller,
    Phase1ToneTokens tokens,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(controller.year, controller.month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh'),
    );
    if (picked != null) {
      await controller.goToMonth(picked.year, picked.month);
    }
  }
}

/// 月历网格（7 列，周一开头）。
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.tokens,
    required this.selectedDate,
    required this.onTap,
  });

  final CalendarMonthData month;
  final Phase1ToneTokens tokens;
  final String? selectedDate;
  final void Function(String date) onTap;

  @override
  Widget build(BuildContext context) {
    final layout = MonthLayout(month.year, month.month);
    final today = DateUtil.todayIso();
    final cells = <Widget>[];

    // 周标题行。
    for (final h in month.weekdayHeaders) {
      cells.add(
        Center(
          child: Text(
            h,
            style: TextStyle(
              color: tokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < layout.gridCells; i++) {
      final dayOffset = i - layout.firstWeekdayIndex;
      final inMonth = dayOffset >= 0 && dayOffset < layout.daysInMonth;
      if (!inMonth) {
        cells.add(const SizedBox.shrink());
        continue;
      }
      final date = DateUtil.iso(DateTime(month.year, month.month, dayOffset + 1));
      final status = month.days[date];
      final isToday = date == today;
      final isSelected = date == selectedDate;
      final isFuture = date.compareTo(today) > 0;
      cells.add(_DayCell(
        date: date,
        dayNumber: dayOffset + 1,
        status: status,
        isToday: isToday,
        isSelected: isSelected,
        isFuture: isFuture,
        tokens: tokens,
        onTap: isFuture ? null : () => onTap(date),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 2,
        childAspectRatio: 0.92,
        children: cells,
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.dayNumber,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.tokens,
    required this.onTap,
  });

  final String date;
  final int dayNumber;
  final CalendarDayStatus? status;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final Phase1ToneTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasMarker = status?.hasMarker ?? false;
    final bg = isSelected
        ? tokens.primary.withValues(alpha: 0.16)
        : (hasMarker
            ? tokens.primary.withValues(alpha: 0.06)
            : Colors.transparent);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? tokens.primary
                : (isToday
                    ? tokens.primary.withValues(alpha: 0.5)
                    : Colors.transparent),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                color: isFuture
                    ? tokens.muted.withValues(alpha: 0.35)
                    : (isToday ? tokens.primary : tokens.text),
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // 标记点：任务进度/快记/复盘。
            if (hasMarker)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((status?.scheduleCount ?? 0) > 0)
                    _dot(_taskColor(status!), tokens),
                  if ((status?.quickNoteCount ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: _dot(tokens.success, tokens),
                    ),
                  if (status?.reviewDone ?? false)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: _dot(tokens.primary, tokens),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _taskColor(CalendarDayStatus s) {
    if (s.scheduleCount == 0) return tokens.muted;
    return s.completedCount == s.scheduleCount
        ? tokens.taskDone // 全完成：蓝实心
        : tokens.taskPart; // 部分：浅蓝
  }

  Widget _dot(Color color, Phase1ToneTokens tokens) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 选中日期的当天摘要卡片。
class _DayDetail extends ConsumerWidget {
  const _DayDetail({
    required this.date,
    required this.status,
    required this.tokens,
  });

  final String date;
  final CalendarDayStatus status;
  final Phase1ToneTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!status.hasContent) {
      // 外层 SingleChildScrollView 接管滚动，此处用普通 Column。
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: GlassPanel(
          tone: tokens.tone,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailHeader(),
                const SizedBox(height: 14),
                Text(
                  '这一天还没有 Daily 内容。',
                  style: TextStyle(color: tokens.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 有内容：解析当天 Daily，就地展示完整明细（日程/快速记录/复盘）。
    return FutureBuilder<DailyDocRead>(
      future: ref.read(dailyMutationServiceProvider).readDaily(date),
      builder: (context, snapshot) {
        // 外层 SingleChildScrollView 接管滚动，此处用普通 Column。
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: GlassPanel(
            tone: tokens.tone,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailHeader(),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: status.progress,
                      minHeight: 6,
                      backgroundColor:
                          tokens.muted.withValues(alpha: 0.18),
                      color: tokens.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState != ConnectionState.done)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: tokens.primary, strokeWidth: 2),
                      ),
                    )
                  else ...[
                    _schedulesSection(snapshot.data?.model.schedules ?? []),
                    const SizedBox(height: 14),
                    _quickNotesSection(snapshot.data?.model.quickNotes ?? []),
                    const SizedBox(height: 14),
                    _reviewSection(snapshot.data?.model.review ?? []),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailHeader() {
    return Row(
      children: [
        Icon(Icons.event_note_outlined, color: tokens.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _friendlyDate(date),
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '${status.completedCount}/${status.scheduleCount}',
          style: TextStyle(
            color: tokens.primary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _schedulesSection(List schedules) {
    if (schedules.isEmpty) return const SizedBox.shrink();
    final sorted = [...schedules]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('日程'),
        const SizedBox(height: 8),
        for (final s in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  s.completed ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: s.completed ? tokens.primary : tokens.muted,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  child: Text(
                    s.startTime,
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: s.completed ? tokens.muted : tokens.text,
                      fontSize: 14,
                      decoration: s.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _quickNotesSection(List quickNotes) {
    if (quickNotes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('快速记录 (${quickNotes.length})'),
        const SizedBox(height: 8),
        for (final q in quickNotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_outlined,
                    color: tokens.primary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.text, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewSection(List review) {
    final filled = review.where((r) => r.content.trim().isNotEmpty).toList();
    if (filled.isEmpty) {
      return _sectionLabel('复盘：未填写');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('复盘 (${filled.length} 项)'),
        const SizedBox(height: 8),
        for (final r in filled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: TextStyle(
                    color: tokens.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.muted, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: tokens.muted,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      );

  String _friendlyDate(String iso) {
    final d = DateUtil.parseIso(iso);
    if (d == null) return iso;
    const w = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.year}年${d.month}月${d.day}日 ${w[d.weekday - 1]}';
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.tokens,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final Phase1ToneTokens tokens;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.muted, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.muted, fontSize: 15),
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
