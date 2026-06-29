import '../../../core/storage/lifescale_db_service.dart';
import '../domain/daily_doc.dart';
import '../domain/quick_note.dart';
import '../domain/schedule.dart';
import '../../../shared/constants/markdown.dart';

/// Daily 结构化实体本地真相源封装（docs/09 SQL-first + 沉淀分层）。
///
/// 与桌面端 `dailyEntities.ts` 1:1 对齐。真相源 = `lifescale.db`。
/// 当天日程/快速记录/复盘/今日重点全在此库 CRUD；当天不写 .md（沉淀 P2 才生成）。
///
/// 实体 ↔ Row 转换约定：
/// - `Schedule.categoryColor`：SQL 不存（category 派生值），读出从 ScheduleCategory 还原
/// - `QuickNote.createdAt`：SQL 存完整 ISO（含 HH:mm:00.000）
/// - `ReviewAnswer.id = questionId`（一题一条）

const String _defaultSourceDevice = 'mobile';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// 某天全部实体聚合（hook 组装 DailyDocModel 的数据源）。
class DailyEntitiesData {
  const DailyEntitiesData({
    required this.schedules,
    required this.quickNotes,
    required this.reviews,
    required this.focus,
  });

  final List<Schedule> schedules;
  final List<QuickNote> quickNotes;
  final List<ReviewEntry> reviews;
  final String? focus;

  bool get isEmpty =>
      schedules.isEmpty && quickNotes.isEmpty && reviews.isEmpty && focus == null;
}

// ============================ 实体 ↔ Row 转换 ============================

ScheduleRow scheduleToRow(Schedule s) {
  final now = _nowIso();
  return ScheduleRow(
    id: s.id,
    date: s.date,
    startTime: s.startTime,
    endTime: s.endTime,
    title: s.title,
    category: s.category.label,
    type: (s.type ?? ScheduleType.task).name,
    completed: s.completed,
    focus: s.focus ?? false,
    sortOrder: s.sortOrder ?? 0,
    settled: false,
    sourceDevice: _defaultSourceDevice,
    createdAt: s.createdAt ?? now,
    updatedAt: now,
    deleted: false,
  );
}

Schedule rowToSchedule(ScheduleRow r) {
  return Schedule(
    id: r.id,
    title: r.title,
    completed: r.completed,
    category: ScheduleCategory.fromLabel(r.category),
    categoryColor: ScheduleCategory.fromLabel(r.category).color,
    type: r.type == 'note' ? ScheduleType.note : ScheduleType.task,
    focus: r.focus,
    sortOrder: r.sortOrder,
    startTime: r.startTime,
    endTime: r.endTime,
    date: r.date,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

QuickNoteRow quickNoteToRow(QuickNote q) {
  return QuickNoteRow(
    id: q.id,
    date: q.date,
    content: q.content,
    sourceDevice: _defaultSourceDevice,
    settled: false,
    createdAt: q.createdAt,
    updatedAt: _nowIso(),
    deleted: q.status == 'deleted',
  );
}

QuickNote rowToQuickNote(QuickNoteRow r) {
  return QuickNote(
    id: r.id,
    date: r.date,
    content: r.content,
    sourceDevice: _defaultSourceDevice,
    status: r.deleted ? 'deleted' : 'active',
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

ReviewAnswerRow reviewEntryToRow(ReviewEntry r, String date) {
  final now = _nowIso();
  return ReviewAnswerRow(
    id: r.questionId,
    date: date,
    questionId: r.questionId,
    title: r.title,
    content: r.content,
    settled: false,
    createdAt: now,
    updatedAt: now,
    deleted: false,
  );
}

ReviewEntry rowToReviewEntry(ReviewAnswerRow r) {
  return ReviewEntry(
    questionId: r.questionId,
    title: r.title,
    content: r.content,
  );
}

// ============================ 读取：loadDailyEntities ============================

Future<DailyEntitiesData> loadDailyEntities(LifescaleDbService db, String date) async {
  final rows = await Future.wait([
    db.listSchedulesByDate(date),
    db.listQuickNotesByDate(date),
    db.listReviewAnswersByDate(date),
    db.getDailyFocus(date),
  ]);
  return DailyEntitiesData(
    schedules: (rows[0] as List<ScheduleRow>).map(rowToSchedule).toList(),
    quickNotes: (rows[1] as List<QuickNoteRow>).map(rowToQuickNote).toList(),
    reviews: (rows[2] as List<ReviewAnswerRow>).map(rowToReviewEntry).toList(),
    focus: (rows[3] as DailyFocusRow?)?.content,
  );
}

// ============================ 批量替换（mutate 写路径）============================
// 策略：先软删当天该类全部实体（墓碑保留供同步/对账），再批量 upsert。

Future<void> batchReplaceSchedules(
    LifescaleDbService db, String date, List<Schedule> schedules) async {
  final now = _nowIso();
  await db.softDeleteSchedulesByDate(date, now);
  for (final s in schedules) {
    await db.upsertSchedule(scheduleToRow(s));
  }
}

Future<void> batchReplaceQuickNotes(
    LifescaleDbService db, String date, List<QuickNote> quickNotes) async {
  final now = _nowIso();
  await db.softDeleteQuickNotesByDate(date, now);
  for (final q in quickNotes) {
    await db.upsertQuickNote(quickNoteToRow(q));
  }
}

Future<void> batchReplaceReviews(
    LifescaleDbService db, String date, List<ReviewEntry> reviews) async {
  final now = _nowIso();
  await db.softDeleteReviewAnswersByDate(date, now);
  for (final r in reviews) {
    await db.upsertReviewAnswer(reviewEntryToRow(r, date));
  }
}

Future<void> upsertDailyFocus(LifescaleDbService db, String date, String? content) async {
  await db.upsertDailyFocus(DailyFocusRow(
    date: date,
    content: content,
    settled: false,
    updatedAt: _nowIso(),
  ));
}

// ============================ 沉淀（docs/09 第七章）============================

/// 沉淀产物目录（docs/09 §6.1.3 与遗留 Daily/ 分离）。
const String settlementVaultDir = 'Notes/Daily';

/// 沉淀产物路径：`Notes/Daily/<date>.md`。
String settlementVaultPath(String date) => '$settlementVaultDir/$date.md';

/// 标记当天 4 类实体 settled=1（docs/09 §7.2 第 5 步）。
Future<void> markDailyEntitiesSettled(LifescaleDbService db, String date) async {
  final now = _nowIso();
  await db.markSchedulesSettledByDate(date, now);
  await db.markQuickNotesSettledByDate(date, now);
  await db.markReviewAnswersSettledByDate(date, now);
  await db.markDailyFocusSettledByDate(date, now);
}
