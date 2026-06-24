import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../shared/constants/markdown.dart';

part 'schedule.freezed.dart';

/// 日程（任务/记录）。字段对齐桌面端 `shared/types/schedule.ts`。
@freezed
class Schedule with _$Schedule {
  const factory Schedule({
    required String id,
    required String title,
    @Default(false) bool completed,
    required ScheduleCategory category,
    required String categoryColor,
    ScheduleType? type,
    bool? focus,
    int? sortOrder,
    required String startTime,
    required String endTime,
    required String date,
    String? createdAt,
    String? updatedAt,
  }) = _Schedule;
}
