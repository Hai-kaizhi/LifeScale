import '../../daily_markdown/domain/daily_doc.dart';
import '../../daily_markdown/domain/quick_note.dart';
import '../../daily_markdown/domain/schedule.dart';
import '../../../shared/constants/markdown.dart';

enum TodaySource { cache, cloud, offlineCache, empty }

enum TodayLoadStatus { loading, ready, empty, error, noPermission }

enum TodayOperationType {
  quickNote,
  taskToggle,
  taskCreate,
  taskUpdate,
  taskDelete,
  taskReorder,
}

enum TodaySyncStatus { clean, pending, conflict, error }

class TodayPermissions {
  const TodayPermissions({
    required this.canView,
    required this.canRefresh,
    required this.canCreateQuickNote,
    required this.canToggleTask,
    required this.canCreateTask,
    required this.canUpdateTask,
    required this.canDeleteTask,
    required this.canFillReview,
    this.reason,
  });

  final bool canView;
  final bool canRefresh;
  final bool canCreateQuickNote;
  final bool canToggleTask;
  final bool canCreateTask;
  final bool canUpdateTask;
  final bool canDeleteTask;
  final bool canFillReview;
  final String? reason;

  bool get canMutateTasks =>
      canToggleTask || canCreateTask || canUpdateTask || canDeleteTask;

  static const editable = TodayPermissions(
    canView: true,
    canRefresh: true,
    canCreateQuickNote: true,
    canToggleTask: true,
    canCreateTask: true,
    canUpdateTask: true,
    canDeleteTask: true,
    canFillReview: true,
  );

  static const readOnly = TodayPermissions(
    canView: true,
    canRefresh: true,
    canCreateQuickNote: false,
    canToggleTask: false,
    canCreateTask: false,
    canUpdateTask: false,
    canDeleteTask: false,
    canFillReview: false,
    reason: '仅今天支持移动端轻操作',
  );

  static const none = TodayPermissions(
    canView: false,
    canRefresh: false,
    canCreateQuickNote: false,
    canToggleTask: false,
    canCreateTask: false,
    canUpdateTask: false,
    canDeleteTask: false,
    canFillReview: false,
    reason: '当前账号暂无权限',
  );
}

class TodayViewData {
  const TodayViewData({
    required this.date,
    required this.title,
    required this.focus,
    required this.schedules,
    required this.quickNotes,
    required this.review,
    required this.source,
    required this.permissions,
    required this.cachedPath,
  });

  final String date;
  final String title;
  final String? focus;
  final List<Schedule> schedules;
  final List<QuickNote> quickNotes;
  final List<ReviewEntry> review;
  final TodaySource source;
  final TodayPermissions permissions;
  final String cachedPath;

  List<Schedule> get tasks =>
      schedules.where((item) => item.type != ScheduleType.note).toList();

  List<Schedule> get timeRecords =>
      schedules.where((item) => item.type == ScheduleType.note).toList();

  int get taskCount => tasks.length;

  int get completedTaskCount => tasks.where((item) => item.completed).length;

  double get progress => taskCount == 0 ? 0 : completedTaskCount / taskCount;

  int get reviewAnsweredCount =>
      review.where((item) => item.content.trim().isNotEmpty).length;

  bool get reviewStarted => reviewAnsweredCount > 0;

  bool get isStructurallyEmpty =>
      (focus == null || focus!.trim().isEmpty) &&
      schedules.isEmpty &&
      quickNotes.isEmpty &&
      review.every((item) => item.content.trim().isEmpty);

  TodayViewData copyWith({
    String? date,
    String? title,
    String? focus,
    bool clearFocus = false,
    List<Schedule>? schedules,
    List<QuickNote>? quickNotes,
    List<ReviewEntry>? review,
    TodaySource? source,
    TodayPermissions? permissions,
    String? cachedPath,
  }) => TodayViewData(
    date: date ?? this.date,
    title: title ?? this.title,
    focus: clearFocus ? null : focus ?? this.focus,
    schedules: schedules ?? this.schedules,
    quickNotes: quickNotes ?? this.quickNotes,
    review: review ?? this.review,
    source: source ?? this.source,
    permissions: permissions ?? this.permissions,
    cachedPath: cachedPath ?? this.cachedPath,
  );
}

class TodayLoadResult {
  const TodayLoadResult({required this.status, this.data, this.message});

  final TodayLoadStatus status;
  final TodayViewData? data;
  final String? message;

  const TodayLoadResult.ready(TodayViewData data)
    : this(status: TodayLoadStatus.ready, data: data);

  const TodayLoadResult.empty([String? message])
    : this(status: TodayLoadStatus.empty, message: message);

  const TodayLoadResult.error(String message, {TodayViewData? fallback})
    : this(status: TodayLoadStatus.error, message: message, data: fallback);

  const TodayLoadResult.noPermission(String message)
    : this(status: TodayLoadStatus.noPermission, message: message);
}

class TodayState {
  const TodayState({
    this.status = TodayLoadStatus.loading,
    this.data,
    this.message,
    this.refreshing = false,
    this.submitting = false,
    this.operationType,
    this.activeOperationId,
    this.syncStatus = TodaySyncStatus.clean,
    this.lastSaveMessage,
  });

  final TodayLoadStatus status;
  final TodayViewData? data;
  final String? message;
  final bool refreshing;
  final bool submitting;
  final TodayOperationType? operationType;
  final String? activeOperationId;
  final TodaySyncStatus syncStatus;
  final String? lastSaveMessage;

  // 注意：tone 字段已移除。时段色调真相统一由 ThemeController 管理
  // （lib/core/theme/theme_controller.dart），不再在 TodayState 重复持有。

  bool get loading => status == TodayLoadStatus.loading;

  TodayState copyWith({
    TodayLoadStatus? status,
    TodayViewData? data,
    bool clearData = false,
    String? message,
    bool clearMessage = false,
    bool? refreshing,
    bool? submitting,
    TodayOperationType? operationType,
    String? activeOperationId,
    bool clearOperation = false,
    TodaySyncStatus? syncStatus,
    String? lastSaveMessage,
    bool clearLastSaveMessage = false,
  }) => TodayState(
    status: status ?? this.status,
    data: clearData ? null : data ?? this.data,
    message: clearMessage ? null : message ?? this.message,
    refreshing: refreshing ?? this.refreshing,
    submitting: submitting ?? this.submitting,
    operationType: clearOperation ? null : operationType ?? this.operationType,
    activeOperationId: clearOperation
        ? null
        : activeOperationId ?? this.activeOperationId,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSaveMessage: clearLastSaveMessage
        ? null
        : lastSaveMessage ?? this.lastSaveMessage,
  );
}

class TodayTaskDraft {
  const TodayTaskDraft({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.category,
    this.type = ScheduleType.task,
  });

  final String title;
  final String startTime;
  final String endTime;
  final ScheduleCategory category;
  final ScheduleType type;
}

class TodayMutationResult {
  const TodayMutationResult({
    required this.data,
    required this.syncStatus,
    required this.message,
  });

  final TodayViewData data;
  final TodaySyncStatus syncStatus;
  final String message;
}
