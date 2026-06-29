import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tone.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/util/date_util.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../daily_markdown/domain/schedule.dart';
import '../../review/data/review_precipitate_service.dart';
import '../data/today_repository.dart';
import '../domain/today_models.dart';

class TodayController extends Notifier<TodayState> {
  @override
  TodayState build() {
    _selectedDate = DateUtil.todayIso();
    Future<void>.microtask(loadToday);
    return const TodayState();
  }

  /// 当前查看的日期（YYYY-MM-DD）。默认今天，可由日期切换 UI 修改。
  String _selectedDate = '';

  String get selectedDate => _selectedDate;

  bool get isToday => _selectedDate == DateUtil.todayIso();

  Future<void> loadToday({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
        refreshing: true,
        clearMessage: true,
        clearLastSaveMessage: true,
        syncStatus: TodaySyncStatus.clean,
      );
    } else {
      state = state.copyWith(
        status: TodayLoadStatus.loading,
        clearData: true,
        clearMessage: true,
        clearLastSaveMessage: true,
        syncStatus: TodaySyncStatus.clean,
      );
    }

    final result = await ref
        .read(todayRepositoryProvider)
        .loadToday(_selectedDate);

    switch (result.status) {
      case TodayLoadStatus.ready:
        state = state.copyWith(
          status: TodayLoadStatus.ready,
          data: result.data,
          refreshing: false,
          message: refresh ? '今日内容已刷新' : null,
          clearMessage: !refresh,
        );
      case TodayLoadStatus.empty:
        // empty 态保留一个空视图（editable），使增删改查在「当天无 Daily」时也能工作：
        // 写入时由 repository 创建当天 Daily 文件。
        // 不弹 message：页面已展示正常的空态布局（各面板「今天还没有…」提示），
        // 无需再用 SnackBar 提示「今天还没有 Daily 内容」。
        state = state.copyWith(
          status: TodayLoadStatus.empty,
          data: TodayViewData(
            date: _selectedDate,
            title: _titleOf(_selectedDate),
            focus: null,
            schedules: const [],
            quickNotes: const [],
            review: const [],
            source: TodaySource.empty,
            permissions: TodayPermissions.editable,
            cachedPath: '',
          ),
          refreshing: false,
          clearMessage: true,
        );
      case TodayLoadStatus.noPermission:
        state = state.copyWith(
          status: TodayLoadStatus.noPermission,
          clearData: true,
          refreshing: false,
          message: result.message ?? '当前账号暂无今日查看权限',
        );
      case TodayLoadStatus.error:
        state = state.copyWith(
          status: TodayLoadStatus.error,
          data: result.data,
          refreshing: false,
          message: result.message ?? '今日内容加载失败',
        );
      case TodayLoadStatus.loading:
        state = state.copyWith(refreshing: false);
    }
  }

  Future<void> refresh() => loadToday(refresh: true);

  Future<bool> addQuickNote(String content) async {
    if (!_ensureTodayEditable('快速记录')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    return _runMutation(
      type: TodayOperationType.quickNote,
      task: () => ref
          .read(todayRepositoryProvider)
          .addQuickNote(_selectedDate, content, previous: previous),
    );
  }

  Future<bool> toggleTask(Schedule item) async {
    if (!_ensureTodayEditable('任务勾选')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    final optimistic = previous.copyWith(
      schedules: previous.schedules.map((schedule) {
        if (schedule.id != item.id) return schedule;
        return schedule.copyWith(completed: !item.completed);
      }).toList(),
    );
    state = state.copyWith(data: optimistic);
    final ok = await _runMutation(
      type: TodayOperationType.taskToggle,
      activeOperationId: item.id,
      task: () => ref
          .read(todayRepositoryProvider)
          .toggleTask(_selectedDate, item.id, !item.completed, previous: previous),
    );
    if (!ok) {
      state = state.copyWith(data: previous);
    }
    return ok;
  }

  Future<bool> createTask(TodayTaskDraft draft) async {
    if (!_ensureTodayEditable('新增日程')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    return _runMutation(
      type: TodayOperationType.taskCreate,
      task: () => ref
          .read(todayRepositoryProvider)
          .createTask(_selectedDate, draft, previous: previous),
    );
  }

  Future<bool> updateTask(String scheduleId, TodayTaskDraft draft) async {
    if (!_ensureTodayEditable('编辑日程')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    return _runMutation(
      type: TodayOperationType.taskUpdate,
      activeOperationId: scheduleId,
      task: () => ref
          .read(todayRepositoryProvider)
          .updateTask(_selectedDate, scheduleId, draft, previous: previous),
    );
  }

  Future<bool> deleteTask(String scheduleId) async {
    if (!_ensureTodayEditable('删除日程')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    return _runMutation(
      type: TodayOperationType.taskDelete,
      activeOperationId: scheduleId,
      task: () => ref
          .read(todayRepositoryProvider)
          .deleteTask(_selectedDate, scheduleId, previous: previous),
    );
  }

  /// 阶段四：拖拽批量重排当天任务。
  /// [orderedIds] 为拖拽后的完整任务 ID 顺序；乐观重排后调后端 reorder，失败回滚。
  Future<bool> reorderTasks(List<String> orderedIds) async {
    if (!_ensureTodayEditable('任务排序')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    // 乐观：按新顺序重排本地任务（保留时间记录在末尾）
    final byId = {for (final s in previous.schedules) s.id: s};
    final reordered = <Schedule>[];
    final rest = <Schedule>[];
    final participated = <String>{};
    for (var i = 0; i < orderedIds.length; i++) {
      final s = byId[orderedIds[i]];
      if (s != null) {
        reordered.add(s.copyWith(sortOrder: i));
        participated.add(orderedIds[i]);
      }
    }
    for (final s in previous.schedules) {
      if (!participated.contains(s.id)) rest.add(s);
    }
    final optimistic = previous.copyWith(schedules: [...reordered, ...rest]);
    state = state.copyWith(data: optimistic);
    final ok = await _runMutation(
      type: TodayOperationType.taskReorder,
      task: () => ref
          .read(todayRepositoryProvider)
          .reorderTasks(_selectedDate, orderedIds, previous: previous),
    );
    if (!ok) {
      state = state.copyWith(data: previous);
    }
    return ok;
  }

  /// 标记 / 取消某日程为今日重点（≤3）。
  Future<bool> toggleFocus(String scheduleId) async {
    if (!_ensureTodayEditable('重点标记')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    return _runMutation(
      type: TodayOperationType.taskUpdate,
      activeOperationId: scheduleId,
      task: () => ref
          .read(todayRepositoryProvider)
          .toggleFocus(_selectedDate, scheduleId, previous: previous),
    );
  }

  /// 编辑自由文本今日重点。
  Future<bool> setFocusText(String text) async {
    if (!_ensureTodayEditable('今日重点')) return false;
    final previous = state.data;
    if (previous == null) {
      state = state.copyWith(message: '今日内容加载中，请稍候');
      return false;
    }
    return _runMutation(
      type: TodayOperationType.taskUpdate,
      task: () => ref
          .read(todayRepositoryProvider)
          .setFocusText(_selectedDate, text, previous: previous),
    );
  }

  /// 阶段五：把当天复盘沉淀为 Vault 文档。
  /// 返回沉淀结果（成功提示 / 失败原因）。
  Future<String> precipitate() async {
    final previous = state.data;
    if (previous == null) return '今日内容加载中，请稍候';
    if (previous.review.every((r) => r.content.trim().isEmpty)) {
      return '请先填写复盘内容，再进行沉淀';
    }
    state = state.copyWith(submitting: true, clearMessage: true);
    try {
      final result = await ref
          .read(reviewPrecipitateServiceProvider)
          .settleDay(_selectedDate);
      // 沉淀后重新加载，保持视图与本地一致。
      await loadToday();
      return result.overwritten
          ? '已重新沉淀到 ${result.mdVaultPath}'
          : (result.status == SettlementStatus.empty
              ? '当天没有可沉淀的内容'
              : '已沉淀到 ${result.mdVaultPath}');
    } on TodayMutationException catch (e) {
      return e.message;
    } catch (_) {
      return '沉淀失败，请稍后重试';
    } finally {
      if (state.submitting) {
        state = state.copyWith(submitting: false, clearOperation: true);
      }
    }
  }

  /// 当前查看的日期（供沉淀/复盘复用）。
  String get reviewDate => _selectedDate;

  /// 切换到指定日期（YYYY-MM-DD），并重新加载该日 Daily。
  /// 不允许选择未来日期（未来没有 Daily）。
  Future<void> changeDate(String date) async {
    if (date == _selectedDate) return;
    if (date.compareTo(DateUtil.todayIso()) > 0) return;
    _selectedDate = date;
    await loadToday();
  }

  /// 前一天。
  Future<void> goPrevDay() async {
    final prev = DateUtil.plusDays(_selectedDate, -1);
    if (prev == null) return;
    await changeDate(prev);
  }

  /// 后一天（不超过今天）。
  Future<void> goNextDay() async {
    final next = DateUtil.plusDays(_selectedDate, 1);
    if (next == null) return;
    await changeDate(next);
  }

  /// 切换时段色调：转发到全局 [ThemeController]（单一真相）。
  void setTone(AppTone tone) {
    ref.read(themeControllerProvider.notifier).setTone(tone);
  }

  /// 日期 → Daily 标题（YYYY年M月D日 周X），供空态视图使用。
  String _titleOf(String date) {
    final d = DateUtil.parseIso(date);
    return d == null ? date : DateUtil.dailyTitle(d);
  }

  void showFutureFeature(String label) {
    state = state.copyWith(message: '$label 当前阶段暂未开发');
  }

  void showDisabled(String label) {
    state = state.copyWith(message: '$label 当前不可用');
  }

  void clearTransient() {
    state = state.copyWith(clearMessage: true);
  }

  // _toneForNow() 已移除：时段判定统一收敛到 ToneTheme.toneForNow()，
  // tone 状态由 ThemeController 持有。

  bool _ensureTodayEditable(String label) {
    // 全面放开增删改查：今天与历史日期均可编辑（不再按日期拦截）。
    if (state.status == TodayLoadStatus.noPermission) {
      state = state.copyWith(message: '当前账号暂无编辑权限');
      return false;
    }
    final permissions = state.data?.permissions ?? TodayPermissions.editable;
    if (!permissions.canCreateQuickNote && !permissions.canMutateTasks) {
      state = state.copyWith(message: permissions.reason ?? '$label 当前不可用');
      return false;
    }
    return true;
  }

  Future<bool> _runMutation({
    required TodayOperationType type,
    String? activeOperationId,
    required Future<TodayMutationResult> Function() task,
  }) async {
    state = state.copyWith(
      submitting: true,
      operationType: type,
      activeOperationId: activeOperationId,
      clearMessage: true,
      clearLastSaveMessage: true,
    );
    try {
      final result = await task();
      final silentCleanToggle =
          type == TodayOperationType.taskToggle &&
          result.syncStatus == TodaySyncStatus.clean;
      state = state.copyWith(
        status: TodayLoadStatus.ready,
        data: result.data,
        submitting: false,
        clearOperation: true,
        syncStatus: result.syncStatus,
        message: silentCleanToggle ? null : result.message,
        clearMessage: silentCleanToggle,
        lastSaveMessage: silentCleanToggle ? null : result.message,
        clearLastSaveMessage: silentCleanToggle,
      );
      return true;
    } on TodayMutationException catch (e) {
      state = state.copyWith(
        submitting: false,
        clearOperation: true,
        syncStatus: TodaySyncStatus.error,
        message: e.message,
        lastSaveMessage: e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        clearOperation: true,
        syncStatus: TodaySyncStatus.error,
        message: '保存失败，请稍后重试',
        lastSaveMessage: '保存失败，请稍后重试',
      );
      return false;
    }
  }
}

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => TodayRepository(ref.watch(dailyMutationServiceProvider)),
);

final todayControllerProvider = NotifierProvider<TodayController, TodayState>(
  TodayController.new,
);
