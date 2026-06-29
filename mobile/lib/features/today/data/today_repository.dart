import '../../../core/storage/vault_storage.dart';
import '../../../core/util/date_util.dart';
import '../../../core/util/id_util.dart';
import '../../daily_markdown/data/daily_mutation_service.dart';
import '../../daily_markdown/domain/daily_doc.dart';
import '../../daily_markdown/domain/quick_note.dart';
import '../../daily_markdown/domain/schedule.dart';
import '../domain/today_models.dart';

/// 今日页仓库：数据源为 **Daily Markdown**（单一事实来源，遵守 doc05 §14.4）。
///
/// 读取：本地优先 → 缓存缺失拉云端 → `DailyDocParser` 解析为 TodayViewData。
/// 写入：快速记录 / 任务增删改勾选 / 重点标记，均通过 [DailyMutationService]
/// 对当天 `Daily/<date>.md` 做「读-改-整文 serialize-落本地-联网 PUT」，
/// 同步走 `/api/vault/files`（乐观锁 + 三方合并 + 冲突副本），与桌面端完全一致。
class TodayRepository {
  const TodayRepository(this._mutation);

  final DailyMutationService _mutation;

  /// 每天最多重点数（与桌面端 `MAX_FOCUS_PER_DAY` 一致）。
  static const int maxFocusPerDay = 3;

  // ============================ 读取 ============================

  Future<TodayLoadResult> loadToday(String date) async {
    try {
      final read = await _mutation.readDaily(date);
      final data = _toViewData(date, read.model);
      // 结构化空（四块全无内容）→ empty 态，便于 UI 展示空状态。
      if (data.isStructurallyEmpty) {
        return TodayLoadResult.empty(date == DateUtil.todayIso()
            ? '今天还没有 Daily 内容'
            : '这一天还没有 Daily 内容');
      }
      return TodayLoadResult.ready(data);
    } catch (e) {
      return TodayLoadResult.error('今日内容加载失败：$e');
    }
  }

  // ============================ 快速记录写入 ============================

  /// 新增快速记录 → 写入当天 Daily 的「快速记录」段。
  Future<TodayMutationResult> addQuickNote(
    String date,
    String content, {
    required TodayViewData previous,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const TodayMutationException('请输入快速记录内容');
    }
    final now = _nowIso();
    final note = QuickNote(
      id: IdUtil.newId(),
      date: date,
      content: trimmed,
      sourceDevice: 'mobile',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(quickNotes: [...base.quickNotes, note]),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已保存',
    );
  }

  /// 删除快速记录 → 从「快速记录」段移除对应 qn id。
  Future<TodayMutationResult> deleteQuickNote(
    String date,
    String noteId, {
    required TodayViewData previous,
  }) async {
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(
        quickNotes:
            base.quickNotes.where((q) => q.id != noteId).toList(),
      ),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已删除',
    );
  }

  // ============================ 任务写入 ============================

  /// 勾选完成 / 取消完成。
  Future<TodayMutationResult> toggleTask(
    String date,
    String scheduleId,
    bool completed, {
    required TodayViewData previous,
  }) async {
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(
        schedules: base.schedules
            .map((s) => s.id == scheduleId
                ? s.copyWith(completed: completed)
                : s)
            .toList(),
      ),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已保存',
    );
  }

  /// 新增任务日程。
  Future<TodayMutationResult> createTask(
    String date,
    TodayTaskDraft draft, {
    required TodayViewData previous,
  }) async {
    final order = _nextSortOrder(previous.schedules);
    final schedule = Schedule(
      id: IdUtil.newId(),
      title: draft.title.trim(),
      completed: false,
      category: draft.category,
      categoryColor: draft.category.color,
      type: draft.type,
      startTime: draft.startTime,
      endTime: draft.endTime,
      date: date,
      sortOrder: order,
    );
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(schedules: [...base.schedules, schedule]),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已保存',
    );
  }

  /// 编辑任务日程（标题 / 时间 / 类别 / 类型）。
  Future<TodayMutationResult> updateTask(
    String date,
    String scheduleId,
    TodayTaskDraft draft, {
    required TodayViewData previous,
  }) async {
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(
        schedules: base.schedules
            .map((s) => s.id == scheduleId
                ? s.copyWith(
                    title: draft.title.trim(),
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    category: draft.category,
                    categoryColor: draft.category.color,
                    type: draft.type,
                  )
                : s)
            .toList(),
      ),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已保存',
    );
  }

  /// 删除任务日程。
  Future<TodayMutationResult> deleteTask(
    String date,
    String scheduleId, {
    required TodayViewData previous,
  }) async {
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(
        schedules:
            base.schedules.where((s) => s.id != scheduleId).toList(),
      ),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已删除',
    );
  }

  /// 拖拽批量重排当天任务顺序。[orderedIds] 为拖拽后的完整任务顺序。
  Future<TodayMutationResult> reorderTasks(
    String date,
    List<String> orderedIds, {
    required TodayViewData previous,
  }) async {
    final model = await _mutation.mutate(date, (base) {
      final byId = {for (final s in base.schedules) s.id: s};
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
      for (final s in base.schedules) {
        if (!participated.contains(s.id)) rest.add(s);
      }
      return base.copyWith(schedules: [...reordered, ...rest]);
    });
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '顺序已更新',
    );
  }

  // ============================ 今日重点（focus 标记） ============================

  /// 标记 / 取消某日程为重点（≤3）。超限抛异常。
  Future<TodayMutationResult> toggleFocus(
    String date,
    String scheduleId, {
    required TodayViewData previous,
  }) async {
    final current = previous.schedules.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => throw const TodayMutationException('日程不存在'),
    );
    final willBeFocus = !(current.focus ?? false);
    if (willBeFocus) {
      final focusCount =
          previous.schedules.where((s) => s.focus == true).length;
      if (focusCount >= maxFocusPerDay) {
        throw const TodayMutationException('每天最多 $maxFocusPerDay 个重点');
      }
    }
    final model = await _mutation.mutate(
      date,
      (base) => base.copyWith(
        schedules: base.schedules
            .map((s) =>
                s.id == scheduleId ? s.copyWith(focus: willBeFocus) : s)
            .toList(),
      ),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: willBeFocus ? '已标记为重点' : '已取消重点',
    );
  }

  /// 编辑自由文本今日重点（model.focus）。
  Future<TodayMutationResult> setFocusText(
    String date,
    String? text, {
    required TodayViewData previous,
  }) async {
    final trimmed = text?.trim();
    final model = await _mutation.mutate(
      date,
      (base) =>
          base.copyWith(focus: (trimmed == null || trimmed.isEmpty) ? null : trimmed),
    );
    return TodayMutationResult(
      data: _rebuildFrom(previous, model),
      syncStatus: TodaySyncStatus.clean,
      message: '已保存',
    );
  }

  // ============================ 映射 / 工具 ============================

  TodayViewData _toViewData(String date, DailyDocModel model) {
    return TodayViewData(
      date: date,
      title: model.title.isEmpty ? _dailyTitle(date) : model.title,
      focus: model.focus,
      schedules: model.schedules,
      quickNotes: model.quickNotes,
      review: model.review,
      source: TodaySource.cloud,
      permissions: _permissionsFor(date),
      cachedPath: VaultStorage.resolveVaultPath(
        'Daily/$date.md',
      ),
    );
  }

  /// 基于上一份视图重建：保留 source/permissions/cachedPath，替换为最新 model。
  TodayViewData _rebuildFrom(TodayViewData previous, DailyDocModel model) {
    return TodayViewData(
      date: previous.date,
      title: model.title.isEmpty ? previous.title : model.title,
      focus: model.focus,
      schedules: model.schedules,
      quickNotes: model.quickNotes,
      review: model.review,
      source: TodaySource.cloud,
      permissions: previous.permissions,
      cachedPath: previous.cachedPath,
    );
  }

  TodayPermissions _permissionsFor(String date) {
    // 全面放开增删改查：今天与历史日期均可编辑（移动端支持完整 CRUD）。
    return TodayPermissions.editable;
  }

  int _nextSortOrder(List<Schedule> schedules) {
    if (schedules.isEmpty) return 0;
    return schedules
            .map((s) => s.sortOrder ?? 0)
            .fold<int>(0, (a, b) => a > b ? a : b) +
        1;
  }

  String _dailyTitle(String date) {
    final d = DateUtil.parseIso(date);
    return d == null ? date : DateUtil.dailyTitle(d);
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();
}

class TodayMutationException implements Exception {
  const TodayMutationException(this.message);

  final String message;

  @override
  String toString() => message;
}
