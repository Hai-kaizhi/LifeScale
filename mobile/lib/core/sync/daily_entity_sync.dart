import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_result.dart';
import '../network/dto/daily_entity_dtos.dart';
import '../providers.dart';
import '../storage/lifescale_db_service.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../features/vault/vault_providers.dart';

/// 当天实体同步（docs/09 §9.3）。
///
/// 当天未沉淀实体（settled=0）跨设备 last-write-wins 同步。游标存 sync.db 的
/// sync_meta（key=daily_entity_sync_cursor）。与桌面 dailyEntitySync.ts 对齐。
class DailyEntitySync {
  DailyEntitySync(this._vaultRepo, this._lsDb);

  final VaultRepository _vaultRepo;
  final LifescaleDbService _lsDb;

  static const String _cursorKey = 'daily_entity_sync_cursor';

  /// 单轮实体同步：push 后 pull。由 SyncEngine.flushPending 末尾调用。
  Future<void> syncOnce() async {
    await pushUnsettledEntities();
    await pullEntityChanges();
  }

  /// push：本地未沉淀实体推到云端（LWW 由服务端裁决）。
  Future<void> pushUnsettledEntities() async {
    final rows = await Future.wait([
      _lsDb.listAllUnsettledSchedules(),
      _lsDb.listAllUnsettledQuickNotes(),
      _lsDb.listAllUnsettledReviewAnswers(),
      _lsDb.listAllUnsettledDailyFocus(),
    ]);
    final schedules = rows[0] as List<ScheduleRow>;
    final quickNotes = rows[1] as List<QuickNoteRow>;
    final reviews = rows[2] as List<ReviewAnswerRow>;
    final focus = rows[3] as List<DailyFocusRow>;

    if (schedules.isEmpty && quickNotes.isEmpty && reviews.isEmpty && focus.isEmpty) {
      return; // 无未沉淀数据，跳过
    }

    final payload = DailyEntityPushPayload(
      schedules: schedules.map(_scheduleRowToDto).toList(),
      quickNotes: quickNotes.map(_quickNoteRowToDto).toList(),
      reviewAnswers: reviews.map(_reviewAnswerRowToDto).toList(),
      dailyFocuses: focus.map(_dailyFocusRowToDto).toList(),
      deviceId: _vaultRepo.deviceId(),
    );
    await _vaultRepo.pushDailyEntities(payload);
  }

  /// pull：增量拉取远端变更，对每条 LWW 写本地（远端 updatedAt 晚于本地才覆盖）。
  Future<void> pullEntityChanges() async {
    final cursor = await _vaultRepo.getMeta(_cursorKey);
    final res = await _vaultRepo.getDailyEntityChanges(since: cursor, limit: 200);
    switch (res) {
      case ApiSuccess(:final data):
        // LWW 写本地。
        for (final s in data.schedules) {
          await _upsertScheduleIfNewer(s);
        }
        for (final q in data.quickNotes) {
          await _upsertQuickNoteIfNewer(q);
        }
        for (final r in data.reviewAnswers) {
          await _upsertReviewAnswerIfNewer(r);
        }
        for (final f in data.dailyFocuses) {
          await _upsertDailyFocusIfNewer(f);
        }
        await _vaultRepo.setMeta(_cursorKey, data.nextCursor);
      case ApiFailure():
        break; // 网络失败：保持旧游标，下次重试。
    }
  }

  // ============================ DTO ↔ Row ============================

  ScheduleMirrorData _scheduleRowToDto(ScheduleRow r) => ScheduleMirrorData(
        id: r.id,
        date: r.date,
        startTime: r.startTime,
        endTime: r.endTime,
        title: r.title,
        category: r.category,
        type: r.type,
        completed: r.completed,
        focus: r.focus,
        sortOrder: r.sortOrder,
        settled: r.settled,
        deleted: r.deleted,
        updatedAt: r.updatedAt,
      );

  QuickNoteMirrorData _quickNoteRowToDto(QuickNoteRow r) => QuickNoteMirrorData(
        id: r.id,
        date: r.date,
        content: r.content,
        settled: r.settled,
        deleted: r.deleted,
        updatedAt: r.updatedAt,
      );

  ReviewAnswerMirrorData _reviewAnswerRowToDto(ReviewAnswerRow r) => ReviewAnswerMirrorData(
        id: r.id,
        date: r.date,
        questionId: r.questionId,
        title: r.title,
        content: r.content,
        settled: r.settled,
        deleted: r.deleted,
        updatedAt: r.updatedAt,
      );

  DailyFocusMirrorData _dailyFocusRowToDto(DailyFocusRow r) => DailyFocusMirrorData(
        date: r.date,
        content: r.content,
        settled: r.settled,
        deleted: false,
        updatedAt: r.updatedAt,
      );

  // ============================ LWW 写本地 ============================

  Future<void> _upsertScheduleIfNewer(ScheduleMirrorData dto) async {
    final local = (await _lsDb.listSchedulesByDate(dto.date, includeDeleted: true))
        .where((r) => r.id == dto.id)
        .firstOrNull;
    if (local != null && local.updatedAt.compareTo(dto.updatedAt) >= 0) return;
    await _lsDb.upsertSchedule(ScheduleRow(
      id: dto.id,
      date: dto.date,
      startTime: dto.startTime,
      endTime: dto.endTime,
      title: dto.title,
      category: dto.category,
      type: dto.type,
      completed: dto.completed,
      focus: dto.focus,
      sortOrder: dto.sortOrder,
      settled: dto.settled,
      sourceDevice: null,
      createdAt: dto.updatedAt,
      updatedAt: dto.updatedAt,
      deleted: dto.deleted,
    ));
  }

  Future<void> _upsertQuickNoteIfNewer(QuickNoteMirrorData dto) async {
    final local = (await _lsDb.listQuickNotesByDate(dto.date, includeDeleted: true))
        .where((r) => r.id == dto.id)
        .firstOrNull;
    if (local != null && local.updatedAt.compareTo(dto.updatedAt) >= 0) return;
    await _lsDb.upsertQuickNote(QuickNoteRow(
      id: dto.id,
      date: dto.date,
      content: dto.content,
      sourceDevice: null,
      settled: dto.settled,
      createdAt: dto.updatedAt,
      updatedAt: dto.updatedAt,
      deleted: dto.deleted,
    ));
  }

  Future<void> _upsertReviewAnswerIfNewer(ReviewAnswerMirrorData dto) async {
    final local = (await _lsDb.listReviewAnswersByDate(dto.date, includeDeleted: true))
        .where((r) => r.id == dto.id)
        .firstOrNull;
    if (local != null && local.updatedAt.compareTo(dto.updatedAt) >= 0) return;
    await _lsDb.upsertReviewAnswer(ReviewAnswerRow(
      id: dto.id,
      date: dto.date,
      questionId: dto.questionId,
      title: dto.title,
      content: dto.content,
      settled: dto.settled,
      createdAt: dto.updatedAt,
      updatedAt: dto.updatedAt,
      deleted: dto.deleted,
    ));
  }

  Future<void> _upsertDailyFocusIfNewer(DailyFocusMirrorData dto) async {
    final local = await _lsDb.getDailyFocus(dto.date);
    if (local != null && local.updatedAt.compareTo(dto.updatedAt) >= 0) return;
    await _lsDb.upsertDailyFocus(DailyFocusRow(
      date: dto.date,
      content: dto.content,
      settled: dto.settled,
      updatedAt: dto.updatedAt,
    ));
  }
}

/// Provider：依赖 VaultRepository + LifescaleDbService。
final dailyEntitySyncProvider = Provider<DailyEntitySync>(
  (ref) => DailyEntitySync(
    ref.watch(vaultRepositoryProvider),
    ref.watch(lifescaleDbServiceProvider),
  ),
);
