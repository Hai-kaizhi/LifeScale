// Daily 实体同步 DTO 类型（对齐后端 vault.daily.dto，camelCase JSON key）。
// docs/09 §9.3 当天未沉淀实体跨设备 LWW 同步。

/// 日程镜像。id = 客户端实体 UUID（LWW 身份键）。
class ScheduleMirrorData {
  const ScheduleMirrorData({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.category,
    required this.type,
    required this.completed,
    required this.focus,
    required this.sortOrder,
    required this.settled,
    required this.deleted,
    required this.updatedAt,
  });

  final String id;
  final String date;
  final String startTime;
  final String endTime;
  final String title;
  final String category;
  final String type;
  final bool completed;
  final bool focus;
  final int sortOrder;
  final bool settled;
  final bool deleted;
  final String updatedAt;

  factory ScheduleMirrorData.fromJson(Map<String, dynamic> j) => ScheduleMirrorData(
        id: j['id'] as String,
        date: j['date'] as String,
        startTime: j['startTime'] as String,
        endTime: j['endTime'] as String,
        title: j['title'] as String,
        category: j['category'] as String,
        type: j['type'] as String,
        completed: j['completed'] as bool,
        focus: j['focus'] as bool,
        sortOrder: j['sortOrder'] as int,
        settled: j['settled'] as bool,
        deleted: j['deleted'] as bool,
        updatedAt: j['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'title': title,
        'category': category,
        'type': type,
        'completed': completed,
        'focus': focus,
        'sortOrder': sortOrder,
        'settled': settled,
        'deleted': deleted,
        'updatedAt': updatedAt,
      };
}

/// 快速记录镜像。
class QuickNoteMirrorData {
  const QuickNoteMirrorData({
    required this.id,
    required this.date,
    required this.content,
    required this.settled,
    required this.deleted,
    required this.updatedAt,
  });

  final String id;
  final String date;
  final String content;
  final bool settled;
  final bool deleted;
  final String updatedAt;

  factory QuickNoteMirrorData.fromJson(Map<String, dynamic> j) => QuickNoteMirrorData(
        id: j['id'] as String,
        date: j['date'] as String,
        content: j['content'] as String,
        settled: j['settled'] as bool,
        deleted: j['deleted'] as bool,
        updatedAt: j['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'content': content,
        'settled': settled,
        'deleted': deleted,
        'updatedAt': updatedAt,
      };
}

/// 复盘答案镜像。id = questionId。
class ReviewAnswerMirrorData {
  const ReviewAnswerMirrorData({
    required this.id,
    required this.date,
    required this.questionId,
    required this.title,
    required this.content,
    required this.settled,
    required this.deleted,
    required this.updatedAt,
  });

  final String id;
  final String date;
  final String questionId;
  final String title;
  final String content;
  final bool settled;
  final bool deleted;
  final String updatedAt;

  factory ReviewAnswerMirrorData.fromJson(Map<String, dynamic> j) => ReviewAnswerMirrorData(
        id: j['id'] as String,
        date: j['date'] as String,
        questionId: j['questionId'] as String,
        title: j['title'] as String,
        content: j['content'] as String,
        settled: j['settled'] as bool,
        deleted: j['deleted'] as bool,
        updatedAt: j['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'questionId': questionId,
        'title': title,
        'content': content,
        'settled': settled,
        'deleted': deleted,
        'updatedAt': updatedAt,
      };
}

/// 今日重点镜像。date 为业务身份。
class DailyFocusMirrorData {
  const DailyFocusMirrorData({
    required this.date,
    this.content,
    required this.settled,
    required this.deleted,
    required this.updatedAt,
  });

  final String date;
  final String? content;
  final bool settled;
  final bool deleted;
  final String updatedAt;

  factory DailyFocusMirrorData.fromJson(Map<String, dynamic> j) => DailyFocusMirrorData(
        date: j['date'] as String,
        content: j['content'] as String?,
        settled: j['settled'] as bool,
        deleted: j['deleted'] as bool,
        updatedAt: j['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'content': content,
        'settled': settled,
        'deleted': deleted,
        'updatedAt': updatedAt,
      };
}

/// 推送 4 类当天未沉淀实体（批量）。
class DailyEntityPushPayload {
  const DailyEntityPushPayload({
    required this.schedules,
    required this.quickNotes,
    required this.reviewAnswers,
    required this.dailyFocuses,
    this.deviceId,
  });

  final List<ScheduleMirrorData> schedules;
  final List<QuickNoteMirrorData> quickNotes;
  final List<ReviewAnswerMirrorData> reviewAnswers;
  final List<DailyFocusMirrorData> dailyFocuses;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
        'schedules': schedules.map((e) => e.toJson()).toList(),
        'quickNotes': quickNotes.map((e) => e.toJson()).toList(),
        'reviewAnswers': reviewAnswers.map((e) => e.toJson()).toList(),
        'dailyFocuses': dailyFocuses.map((e) => e.toJson()).toList(),
        'deviceId': deviceId,
      };
}

/// /vault/daily-entities/changes 返回：4 类增量变更 + 游标。
class DailyEntityChangesData {
  const DailyEntityChangesData({
    required this.schedules,
    required this.quickNotes,
    required this.reviewAnswers,
    required this.dailyFocuses,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ScheduleMirrorData> schedules;
  final List<QuickNoteMirrorData> quickNotes;
  final List<ReviewAnswerMirrorData> reviewAnswers;
  final List<DailyFocusMirrorData> dailyFocuses;
  final String nextCursor;
  final bool hasMore;

  factory DailyEntityChangesData.fromJson(Map<String, dynamic> j) => DailyEntityChangesData(
        schedules: ((j['schedules'] as List?) ?? const [])
            .map((e) => ScheduleMirrorData.fromJson(e as Map<String, dynamic>))
            .toList(),
        quickNotes: ((j['quickNotes'] as List?) ?? const [])
            .map((e) => QuickNoteMirrorData.fromJson(e as Map<String, dynamic>))
            .toList(),
        reviewAnswers: ((j['reviewAnswers'] as List?) ?? const [])
            .map((e) => ReviewAnswerMirrorData.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyFocuses: ((j['dailyFocuses'] as List?) ?? const [])
            .map((e) => DailyFocusMirrorData.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['nextCursor'] as String,
        hasMore: j['hasMore'] as bool,
      );
}

/// 推送结果：覆盖数 / 丢弃数（LWW 旧版本被跳过）。
class DailyEntitySyncResult {
  const DailyEntitySyncResult({required this.pushed, required this.skipped});

  final int pushed;
  final int skipped;

  factory DailyEntitySyncResult.fromJson(Map<String, dynamic> j) => DailyEntitySyncResult(
        pushed: j['pushed'] as int,
        skipped: j['skipped'] as int,
      );
}
