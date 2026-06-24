import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/util/date_util.dart';
import '../../../shared/widgets/month_calendar_picker.dart';
import '../../../shared/constants/markdown.dart';
import '../../daily_markdown/domain/quick_note.dart';
import '../../daily_markdown/domain/schedule.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';
import '../../review/domain/review_models.dart';
import '../../review/presentation/review_controller.dart';
import '../domain/today_models.dart';
import 'today_controller.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayControllerProvider);
    final controller = ref.read(todayControllerProvider.notifier);
    // 时段色调由全局 ThemeController 统一管理（单一真相）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);

    ref.listen<TodayState>(todayControllerProvider, (_, next) {
      final message = next.message;
      if (message == null || message.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
      Future<void>.microtask(controller.clearTransient);
    });

    // 监听 AppShell 中央「+」创建信号：值变化时打开创建菜单。
    // （IndexedStack 子页无法直接拿到 AppShell 回调，用 riverpod provider 传递。）
    ref.listen<int>(
      todayCreateSignalProvider.select((n) => n.value),
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              color: tokens.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 110),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(
                          state: state,
                          tokens: tokens,
                          tone: tone,
                        ),
                        const SizedBox(height: 16),
                        ToneSegmentedControl(
                          value: tone,
                          onChanged: controller.setTone,
                        ),
                        const SizedBox(height: 18),
                        _TodayBody(state: state, tokens: tokens, tone: tone),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.state,
    required this.tokens,
    required this.tone,
  });

  final TodayState state;
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(todayControllerProvider.notifier);
    final data = state.data;
    final title = switch (tone) {
      TodayTone.morning => '早安',
      TodayTone.afternoon => '下午',
      TodayTone.night => '夜晚',
    };
    final subtitle = data == null ? '今日轻量查看' : data.title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: tokens.text,
                  fontSize: tone == TodayTone.afternoon ? 23 : 27,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 右上角：日期选择按钮（紧凑徽标，点击弹日期选择器切换日期）。
        _DatePickButton(
          tokens: tokens,
          date: controller.selectedDate,
          onPick: (picked) => controller.changeDate(DateUtil.iso(picked)),
        ),
      ],
    );
  }
}

/// 右上角日期按钮：日历图标，点击弹出月历弹层（带日期标记，与回看页一致）选择日期。
class _DatePickButton extends StatelessWidget {
  const _DatePickButton({
    required this.tokens,
    required this.date,
    required this.onPick,
  });

  final Phase1ToneTokens tokens;
  final String date; // YYYY-MM-DD
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final d = DateUtil.parseIso(date) ?? DateTime.now();
    final isToday = date == DateUtil.todayIso();
    return GestureDetector(
      onTap: () => showMonthCalendarPicker(
        context,
        tokens,
        initialDate: d,
        onPicked: onPick,
      ),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday ? tokens.primary : tokens.card,
          border:
              isToday ? null : Border.all(color: tokens.cardBorder),
        ),
        child: Icon(
          isToday ? Icons.event_available : Icons.calendar_month_outlined,
          color: isToday ? Colors.white : tokens.primary,
          size: 20,
        ),
      ),
    );
  }
}
/// 复用 TodayRepository.loadToday(date)，仅查看（只读），不实现阶段六的日历回看。
class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.state, required this.tokens, required this.tone});

  final TodayState state;
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(todayControllerProvider.notifier);
    switch (state.status) {
      case TodayLoadStatus.loading:
        return _LoadingCards(tokens: tokens, tone: tone);
      case TodayLoadStatus.noPermission:
        return _StatePanel(
          tone: tone,
          tokens: tokens,
          icon: Icons.lock_outline,
          title: '暂无查看权限',
          message: '当前账号没有移动端今日查看权限，请在桌面端或账号设置中确认。',
          actionLabel: '重试',
          onAction: controller.refresh,
        );
      case TodayLoadStatus.error:
        return _StatePanel(
          tone: tone,
          tokens: tokens,
          icon: Icons.cloud_off_outlined,
          title: '今日内容加载失败',
          message: state.message ?? '网络不可用，且本地没有可展示的缓存。',
          actionLabel: '重试',
          onAction: controller.refresh,
        );
      case TodayLoadStatus.empty:
      case TodayLoadStatus.ready:
        // empty 与 ready 共用同一套正常布局：空态时 controller 已注入一个空的
        // TodayViewData（permissions=editable），各面板内部展示「今天还没有日程 /
        // 快速记录 / 等待补充复盘」等提示，用户经各面板「新增」或顶部「+」创建，
        // 写入时 repository 会自动创建当天 Daily 文件（不再用独立空态编辑器
        // 引导「先记一条」）。
        final data = state.data;
        if (data == null) {
          return _StatePanel(
            tone: tone,
            tokens: tokens,
            icon: Icons.event_note_outlined,
            title: '暂无今日内容',
            message: '没有可展示的 Daily Markdown。',
            actionLabel: '重新拉取',
            onAction: controller.refresh,
          );
        }
        return Column(
          children: [
            _OverviewPanel(data: data, tokens: tokens, tone: tone),
            if (state.lastSaveMessage != null) ...[
              const SizedBox(height: 10),
              _SaveStatusBanner(state: state, tokens: tokens),
            ],
            const SizedBox(height: 14),
            _SchedulePanel(
              state: state,
              data: data,
              tokens: tokens,
              tone: tone,
            ),
            const SizedBox(height: 14),
            _QuickNotesPanel(data: data, tokens: tokens, tone: tone),
            const SizedBox(height: 14),
            _ReviewStatusPanel(data: data, tokens: tokens, tone: tone),
            // 沉淀入口已移至复盘面板右上角（跳转复盘页执行沉淀），
            // 不再单独占一张底部卡片。
          ],
        );
    }
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.data,
    required this.tokens,
    required this.tone,
  });

  final TodayViewData data;
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: tone,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          ProgressRing(
            progress: data.progress,
            color: tokens.primary,
            size: 82,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricLine(
                  tokens: tokens,
                  icon: Icons.check_circle_outline,
                  text: '任务 ${data.completedTaskCount} / ${data.taskCount}',
                ),
                _MetricLine(
                  tokens: tokens,
                  icon: Icons.edit_note_outlined,
                  text: '快速记录 ${data.quickNotes.length} 条',
                ),
                _MetricLine(
                  tokens: tokens,
                  icon: Icons.nightlight_round,
                  text: data.reviewStarted
                      ? '复盘已填写 ${data.reviewAnsweredCount} 项'
                      : '复盘等待晚上补充',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveStatusBanner extends StatelessWidget {
  const _SaveStatusBanner({required this.state, required this.tokens});

  final TodayState state;
  final Phase1ToneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state.syncStatus) {
      TodaySyncStatus.clean => (Icons.cloud_done_outlined, tokens.primary),
      TodaySyncStatus.pending => (
        Icons.cloud_queue_outlined,
        tokens.warning,
      ),
      TodaySyncStatus.conflict => (
        Icons.report_problem_outlined,
        tokens.error,
      ),
      TodaySyncStatus.error => (Icons.error_outline, tokens.error),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.lastSaveMessage ?? '',
              style: TextStyle(
                color: tokens.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulePanel extends ConsumerWidget {
  const _SchedulePanel({
    required this.state,
    required this.data,
    required this.tokens,
    required this.tone,
  });

  final TodayState state;
  final TodayViewData data;
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(todayControllerProvider.notifier);
    // 任务与记录合并为单一列表，按起始时间升序显示（不区分分区、不支持拖拽）。
    final all = [...data.schedules]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final creating =
        state.submitting &&
        state.operationType == TodayOperationType.taskCreate;
    return GlassPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: '今日日程',
            tokens: tokens,
            action: '新增',
            onAction: () =>
                showTaskEditorSheet(context, ref, tokens, initial: null),
          ),
          const SizedBox(height: 12),
          if (creating) ...[
            _PendingLine(tokens: tokens, text: '正在保存新日程…'),
            const SizedBox(height: 8),
          ],
          if (all.isEmpty)
            _InlineEmpty(tokens: tokens, text: '今天还没有日程')
          else
            for (final item in all)
              _ScheduleRow(
                item: item,
                tokens: tokens,
                canToggle: true,
                busy: state.submitting &&
                    state.activeOperationId == item.id &&
                    (state.operationType ==
                            TodayOperationType.taskToggle ||
                        state.operationType ==
                            TodayOperationType.taskUpdate ||
                        state.operationType ==
                            TodayOperationType.taskDelete),
                onTap: () => showTaskEditorSheet(
                  context,
                  ref,
                  tokens,
                  initial: item,
                ),
                onToggle: () => controller.toggleTask(item),
              ),
        ],
      ),
    );
  }
}
class _QuickNotesPanel extends ConsumerWidget {
  const _QuickNotesPanel({
    required this.data,
    required this.tokens,
    required this.tone,
  });

  final TodayViewData data;
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = data.quickNotes.reversed.take(3).toList();
    return GlassPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: '快速记录',
            tokens: tokens,
            action: '新增',
            onAction: () => showQuickNoteCreateSheet(context, tokens),
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            _InlineEmpty(tokens: tokens, text: '今天还没有快速记录')
          else
            for (final note in notes)
              _QuickNoteRow(
                note: note,
                tokens: tokens,
                onTap: () => _showQuickNoteSheet(context, note, tokens),
              ),
        ],
      ),
    );
  }
}

class _ReviewStatusPanel extends ConsumerWidget {
  const _ReviewStatusPanel({
    required this.data,
    required this.tokens,
    required this.tone,
  });

  final TodayViewData data;
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(todayControllerProvider.notifier);
    // 异步加载完整复盘方案（方案全部题目 + 当天答案），与复盘页一致，
    // 避免「外面显示 2 个、里面 4 个」（此前 data.review 仅来自文档解析，不全）。
    final reviewFuture = ref
        .read(reviewRepositoryProvider)
        .loadReview(data.date)
        .then((r) => r.data);
    // 点击任意题目或右上角按钮，都直接跳转到复盘专门页面。
    void goToReview() =>
        context.push('/review?date=${controller.reviewDate}');
    return GlassPanel(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            title: '复盘状态',
            tokens: tokens,
            action: data.reviewStarted ? '查看' : '待填写',
            onAction: goToReview,
            // 右上角沉淀按钮：跳转到复盘专门页面（沉淀在复盘页内执行）。
            trailing: IconButton(
              tooltip: '沉淀',
              icon: const Icon(Icons.auto_awesome_outlined, size: 20),
              color: tokens.primary,
              onPressed: goToReview,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<ReviewViewData?>(
            future: reviewFuture,
            builder: (context, snapshot) {
              // 加载中 / 失败：回退到文档解析的题目，保证不空白。
              final items = snapshot.data?.items;
              if (items == null || items.isEmpty) {
                final fallback = data.review.take(4).toList();
                if (fallback.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '暂无复盘方案',
                      style: TextStyle(color: tokens.muted, fontSize: 13),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final e in fallback)
                      _reviewTile(context, e.title, e.content, goToReview),
                  ],
                );
              }
              // 完整方案题目（含未填写的），与复盘页数量一致。
              return Column(
                children: [
                  for (final item in items)
                    _reviewTile(
                      context,
                      item.question.title,
                      item.answer,
                      goToReview,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(
    BuildContext context,
    String title,
    String content,
    VoidCallback onTap,
  ) {
    final answered = content.trim().isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: tokens.primary.withValues(alpha: 0.12),
        child: Icon(
          answered ? Icons.check_circle : Icons.radio_button_unchecked,
          color: tokens.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: tokens.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        answered ? content : '等待补充',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tokens.muted),
      ),
      trailing: Icon(Icons.chevron_right, color: tokens.muted),
      onTap: onTap,
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.item,
    required this.tokens,
    required this.onTap,
    required this.onToggle,
    required this.canToggle,
    required this.busy,
  });

  final Schedule item;
  final Phase1ToneTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool canToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isRecord = item.type == ScheduleType.note;
    final isFocus = item.focus == true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          // 重点日程：主色淡背景 + 左侧主色竖条，醒目标记（替代独立重点模块）。
          decoration: BoxDecoration(
            color: isFocus ? tokens.primary.withValues(alpha: 0.10) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              // 左侧主色竖条（仅重点）。
              Container(
                width: 3,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isFocus ? tokens.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              GestureDetector(
                onTap: busy ? null : onToggle,
                child: SizedBox.square(
                  dimension: 24,
                  child: busy
                      ? CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.primary,
                        )
                      : Icon(
                          isRecord
                              ? Icons.history_edu_outlined
                              : (item.completed
                                    ? Icons.check_circle
                                    : Icons.circle_outlined),
                          color: canToggle
                              ? (item.completed ? tokens.primary : tokens.muted)
                              : tokens.muted.withValues(alpha: 0.45),
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                child: Text(
                  item.startTime,
                  style: TextStyle(
                    color: isFocus ? tokens.primary : tokens.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // 重点 + 未完成：标题用主色高亮；完成则统一 muted + 删除线。
                    color: (isFocus && !item.completed)
                        ? tokens.primary
                        : (item.completed ? tokens.muted : tokens.text),
                    fontSize: 15,
                    fontWeight: isFocus
                        ? FontWeight.w900
                        : FontWeight.w700,
                    decoration: item.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.category.label,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNoteRow extends StatelessWidget {
  const _QuickNoteRow({
    required this.note,
    required this.tokens,
    required this.onTap,
  });

  final QuickNote note;
  final Phase1ToneTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: tokens.primary.withValues(alpha: 0.12),
        child: Icon(Icons.edit_outlined, color: tokens.primary, size: 18),
      ),
      title: Text(
        note.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _timeFromIso(note.createdAt),
        style: TextStyle(color: tokens.muted),
      ),
      trailing: Icon(Icons.chevron_right, color: tokens.muted),
      onTap: onTap,
    );
  }
}

class _QuickNoteComposer extends StatefulWidget {
  const _QuickNoteComposer({
    required this.tokens,
    required this.enabled,
    required this.submitting,
    required this.onSubmit,
  });

  final Phase1ToneTokens tokens;
  final bool enabled;
  final bool submitting;
  final Future<bool> Function(String content) onSubmit;

  @override
  State<_QuickNoteComposer> createState() => _QuickNoteComposerState();
}

class _QuickNoteComposerState extends State<_QuickNoteComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.submitting;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: widget.tokens.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.tokens.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.enabled ? null : '当前不可记录',
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(
                color: widget.tokens.text,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? _submit : null,
            icon: widget.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 19),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: widget.tokens.primary,
              disabledBackgroundColor: widget.tokens.primary.withValues(
                alpha: 0.24,
              ),
              fixedSize: const Size(42, 42),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.submitting || !widget.enabled) return;
    final ok = await widget.onSubmit(value);
    if (ok && mounted) {
      _controller.clear();
    }
  }
}

class _PendingLine extends StatelessWidget {
  const _PendingLine({required this.tokens, required this.text});

  final Phase1ToneTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: tokens.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.tone,
    required this.tokens,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final TodayTone tone;
  final Phase1ToneTokens tokens;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: tone,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        children: [
          Icon(icon, color: tokens.primary, size: 48),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards({required this.tokens, required this.tone});

  final Phase1ToneTokens tokens;
  final TodayTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          GlassPanel(
            tone: tone,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(tokens: tokens, width: 140),
                const SizedBox(height: 14),
                _SkeletonLine(tokens: tokens, width: double.infinity),
                const SizedBox(height: 10),
                _SkeletonLine(tokens: tokens, width: i.isEven ? 220 : 180),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.tokens, required this.width});

  final Phase1ToneTokens tokens;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: tokens.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.tokens,
    required this.icon,
    required this.text,
  });

  final Phase1ToneTokens tokens;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, color: tokens.primary, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: tokens.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.title,
    required this.tokens,
    this.action,
    this.onAction,
    this.trailing,
  });

  final String title;
  final Phase1ToneTokens tokens;
  final String? action;
  final VoidCallback? onAction;
  // 标题行最右侧的额外控件（如沉淀按钮），位于 action 文本按钮之后。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.tokens, required this.text});

  final Phase1ToneTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: tokens.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: TextStyle(color: tokens.muted)),
    );
  }
}

/// 创建菜单 sheet：快速记录 / 新增日程 / 填写复盘 / AI 提取。
///
/// 公开（无下划线）以便其他页面（如回看页）复用：作用对象由
/// [TodayController.selectedDate] 决定，调用前先把 today 日期切到目标日即可。
void showCreateActionSheet(
  BuildContext context,
  WidgetRef ref,
  Phase1ToneTokens tokens,
) {
  final controller = ref.read(todayControllerProvider.notifier);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor:
        tokens.isDark ? const Color(0xFF11102A) : tokens.card,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_note_outlined, color: tokens.primary),
              title: const Text('快速记录'),
              subtitle: const Text('写入今天的快速记录段'),
              onTap: () {
                Navigator.pop(sheetContext);
                showQuickNoteCreateSheet(context, tokens);
              },
            ),
            ListTile(
              leading: Icon(Icons.add_task_outlined, color: tokens.primary),
              title: const Text('新增日程'),
              subtitle: const Text('添加任务或记录'),
              onTap: () {
                Navigator.pop(sheetContext);
                showTaskEditorSheet(context, ref, tokens, initial: null);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.nightlight_round, color: tokens.primary),
              title: const Text('填写复盘'),
              subtitle: const Text('回顾今天、沉淀收获'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/review?date=${controller.reviewDate}');
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined, color: tokens.muted),
              title: const Text('AI 提取'),
              subtitle: const Text('当前阶段暂未开发'),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.showFutureFeature('AI 提取');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void showQuickNoteCreateSheet(BuildContext context, Phase1ToneTokens tokens) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (context) => QuickNoteCreateSheet(tokens: tokens),
  );
}

class QuickNoteCreateSheet extends ConsumerStatefulWidget {
  const QuickNoteCreateSheet({super.key, required this.tokens});

  final Phase1ToneTokens tokens;

  @override
  ConsumerState<QuickNoteCreateSheet> createState() =>
      QuickNoteCreateSheetState();
}

class QuickNoteCreateSheetState extends ConsumerState<QuickNoteCreateSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);
    final controller = ref.read(todayControllerProvider.notifier);
    final tokens = widget.tokens;
    final submitting =
        state.submitting && state.operationType == TodayOperationType.quickNote;
    final enabled =
        state.status != TodayLoadStatus.noPermission &&
        (state.data?.permissions.canCreateQuickNote ?? true);
    final content = _controller.text.trim();
    final canSubmit = enabled && content.isNotEmpty && !submitting;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.76,
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: BoxDecoration(
                color: tokens.isDark
                    ? const Color(0xFF11102A)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.muted.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: tokens.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.edit_note_outlined,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '快速记录',
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _sheetTimeLabel(),
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: tokens.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 176,
                      maxHeight: 240,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? tokens.primary.withValues(alpha: 0.42)
                            : tokens.primary.withValues(alpha: 0.14),
                        width: _focusNode.hasFocus ? 1.4 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: enabled,
                      enabled: enabled && !submitting,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 7,
                      maxLines: 9,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: enabled ? '写下刚刚发生的事、想法或待办' : '仅支持今天',
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          12,
                        ),
                      ),
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: canSubmit
                          ? () => _submit(context, controller)
                          : null,
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(submitting ? '保存中' : '保存记录'),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: tokens.primary.withValues(
                          alpha: 0.22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, TodayController controller) async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    final ok = await controller.addQuickNote(content);
    if (ok && context.mounted) Navigator.pop(context);
  }

  String _sheetTimeLabel() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '今天 $hh:$mm';
  }
}

class _ScheduleChoiceOption<T> {
  const _ScheduleChoiceOption({
    required this.value,
    required this.iconText,
    required this.label,
    required this.description,
    this.color,
  });

  final T value;
  final String iconText;
  final String label;
  final String description;
  final Color? color;
}

class _ScheduleChoiceGroup<T> extends StatelessWidget {
  const _ScheduleChoiceGroup({
    required this.tokens,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });

  final Phase1ToneTokens tokens;
  final T value;
  final List<_ScheduleChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(child: _buildOption(options[i])),
          if (i != options.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildOption(_ScheduleChoiceOption<T> option) {
    final active = option.value == value;
    final color = option.color ?? tokens.primary;
    return Material(
      color: active
          ? color.withValues(alpha: 0.16)
          : tokens.primary.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? () => onChanged(option.value) : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 82),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.58)
                  : tokens.primary.withValues(alpha: 0.12),
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.iconText,
                  style: TextStyle(
                    color: active ? color : tokens.muted,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? color : tokens.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? color.withValues(alpha: 0.86)
                            : tokens.muted,
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日程编辑 sheet：新增或编辑一条日程（任务/记录）。
///
/// 公开以便回看页复用：作用日由 [TodayController.selectedDate] 决定。
void showTaskEditorSheet(
  BuildContext context,
  WidgetRef ref,
  Phase1ToneTokens tokens, {
  required Schedule? initial,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: tokens.isDark
        ? const Color(0xFF11102A)
        : tokens.card,
    builder: (context) => TaskEditorSheet(tokens: tokens, initial: initial),
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, required this.tokens, required this.initial});

  final Phase1ToneTokens tokens;
  final Schedule? initial;

  @override
  ConsumerState<TaskEditorSheet> createState() => TaskEditorSheetState();
}

class TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  static final RegExp _timeRe = RegExp(r'^\d{2}:\d{2}$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late ScheduleCategory _category;
  late ScheduleType _type;
  late bool _focus;
  late bool _focusInitial;
  bool _saving = false;
  bool _deleting = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _startController = TextEditingController(
      text: initial?.startTime ?? '09:00',
    );
    _endController = TextEditingController(text: initial?.endTime ?? '10:00');
    _category = initial?.category ?? ScheduleCategory.work;
    _type = initial?.type ?? ScheduleType.task;
    _focusInitial = initial?.focus == true;
    _focus = _focusInitial;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final busy = _saving || _deleting;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_task_outlined, color: tokens.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _editing ? '编辑日程' : '新增日程',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: '日程标题',
                  prefixIcon: Icon(Icons.subject_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入日程标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: '开始',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      validator: _validateTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: '结束',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      validator: _validateTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '性质',
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _ScheduleChoiceGroup<ScheduleCategory>(
                tokens: tokens,
                value: _category,
                enabled: !busy,
                options: const [
                  // 分类语义色：与 shared/constants/markdown.dart 的
                  // ScheduleCategory.life.color(#22c55e) 对齐，跨主题保持一致
                  // （用户对「生活=绿 / 工作=蓝」的认知应稳定，不随色调变化）。
                  _ScheduleChoiceOption(
                    value: ScheduleCategory.life,
                    iconText: '🌿',
                    label: '生活',
                    description: '日常起居、运动、休息',
                    color: Color(0xFF22C55E),
                  ),
                  _ScheduleChoiceOption(
                    value: ScheduleCategory.work,
                    iconText: '💼',
                    label: '工作',
                    description: '任务、会议、学习',
                    color: Color(0xFF3B82F6),
                  ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 14),
              Text(
                '类型',
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _ScheduleChoiceGroup<ScheduleType>(
                tokens: tokens,
                value: _type,
                enabled: !busy,
                options: const [
                  _ScheduleChoiceOption(
                    value: ScheduleType.task,
                    iconText: '✓',
                    label: '任务',
                    description: '需要完成，可勾选打卡',
                  ),
                  _ScheduleChoiceOption(
                    value: ScheduleType.note,
                    iconText: '•',
                    label: '记录',
                    description: '仅作备忘，不用打卡',
                  ),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 14),
              // 今日重点标记（≤3）。仅编辑已有日程时可改（新增时无 id，先创建再标记）。
              if (_editing) ...[
                InkWell(
                  onTap: busy
                      ? null
                      : () => setState(() => _focus = !_focus),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: (_focus
                              ? tokens.primary
                              : tokens.muted)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_focus
                                ? tokens.primary
                                : tokens.muted)
                            .withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _focus ? Icons.star : Icons.star_border,
                          color: _focus ? tokens.primary : tokens.muted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '标记为今日重点',
                            style: TextStyle(
                              color: tokens.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Switch(
                          value: _focus,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => _focus = v),
                          activeColor: tokens.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 20),
              Row(
                children: [
                  if (_editing)
                    TextButton.icon(
                      onPressed: busy ? null : _confirmDelete,
                      icon: _deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: busy ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_editing ? '保存' : '新增'),
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateTime(String? value) {
    final text = value?.trim() ?? '';
    if (!_timeRe.hasMatch(text)) return '格式 HH:mm';
    final hour = int.tryParse(text.substring(0, 2));
    final minute = int.tryParse(text.substring(3, 5));
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return '时间无效';
    }
    return null;
  }

  TodayTaskDraft _draft() => TodayTaskDraft(
    title: _titleController.text.trim(),
    startTime: _startController.text.trim(),
    endTime: _endController.text.trim(),
    category: _category,
    type: _type,
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _draft();
    if (draft.startTime.compareTo(draft.endTime) >= 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('结束时间需要晚于开始时间')));
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(todayControllerProvider.notifier);
    final ok = widget.initial == null
        ? await controller.createTask(draft)
        : await controller.updateTask(widget.initial!.id, draft);
    // 重点标记变更（仅编辑已有日程）：在字段保存后单独标记。
    if (ok &&
        widget.initial != null &&
        _focus != _focusInitial) {
      await controller.toggleFocus(widget.initial!.id);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final initial = widget.initial;
    if (initial == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定删除「${initial.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final ok = await ref
        .read(todayControllerProvider.notifier)
        .deleteTask(initial.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (ok) Navigator.pop(context);
  }
}

void _showQuickNoteSheet(
  BuildContext context,
  QuickNote note,
  Phase1ToneTokens tokens,
) {
  _showReadOnlySheet(
    context,
    tokens,
    title: '快速记录',
    icon: Icons.edit_note_outlined,
    lines: [_timeFromIso(note.createdAt), note.content],
  );
}

void _showReadOnlySheet(
  BuildContext context,
  Phase1ToneTokens tokens, {
  required String title,
  required IconData icon,
  required List<String> lines,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tokens.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  style: TextStyle(
                    color: tokens.muted,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _timeFromIso(String value) {
  final match = RegExp(r'T(\d{1,2}:\d{2})').firstMatch(value);
  return match?.group(1) ?? value;
}
