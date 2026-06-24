import '../../../core/theme/app_tone.dart';
import '../../daily_markdown/domain/daily_doc.dart';
import '../../../shared/constants/markdown.dart';

export '../../../core/theme/app_tone.dart';

enum SyncStepStatus { pending, running, success, error }

/// 兼容别名：tone 枚举已迁移到 [AppTone]，保留旧名 [TodayTone] 供历史引用。
/// 新代码请使用 [AppTone]。
typedef TodayTone = AppTone;

class SyncStepView {
  const SyncStepView({
    required this.id,
    required this.title,
    required this.description,
    this.status = SyncStepStatus.pending,
    this.message,
  });

  final String id;
  final String title;
  final String description;
  final SyncStepStatus status;
  final String? message;

  SyncStepView copyWith({SyncStepStatus? status, String? message}) =>
      SyncStepView(
        id: id,
        title: title,
        description: description,
        status: status ?? this.status,
        message: message ?? this.message,
      );
}

class SyncSummary {
  const SyncSummary({
    this.deviceId,
    this.deviceName,
    this.changes = 0,
    this.cachedFiles = 0,
    this.failedFiles = 0,
    this.cursor,
    this.offline = false,
  });

  final String? deviceId;
  final String? deviceName;
  final int changes;
  final int cachedFiles;
  final int failedFiles;
  final String? cursor;
  final bool offline;
}

class TodayPreview {
  const TodayPreview({
    required this.date,
    required this.title,
    required this.model,
    required this.cachedPath,
    required this.syncSummary,
  });

  final String date;
  final String title;
  final DailyDocModel model;
  final String cachedPath;
  final SyncSummary syncSummary;

  int get taskCount =>
      model.schedules.where((item) => item.type != ScheduleType.note).length;

  int get completedTaskCount => model.schedules
      .where((item) => item.type != ScheduleType.note && item.completed)
      .length;

  double get progress {
    final total = taskCount;
    if (total == 0) return 0;
    return completedTaskCount / total;
  }
}
