import '../../../core/network/api_result.dart';
import '../../../core/network/dto/daily_entity_dtos.dart';
import '../../../core/network/dto/vault_dtos.dart';
import '../../../core/storage/database_service.dart';
import '../../../core/storage/prefs_store.dart';
import '../../../core/storage/vault_storage.dart';
import '../../../core/util/date_util.dart';
import '../../../core/util/id_util.dart';
import '../../../shared/constants/markdown.dart';
import '../../daily_markdown/data/daily_doc_serializer.dart';
import '../../daily_markdown/domain/daily_doc.dart';
import '../../daily_markdown/domain/quick_note.dart';
import '../../daily_markdown/domain/schedule.dart';
import 'vault_api.dart';

/// Vault 仓库：组合远程同步 + 本地文件缓存。
class VaultRepository {
  VaultRepository(this._api, this._db, this._prefs);

  final VaultApi _api;
  final DatabaseService _db;
  final PrefsStore _prefs;

  Future<ApiResult<VaultChangesData>> changes({String? since, int? limit}) =>
      _api.changes(since: since, limit: limit);

  Future<ApiResult<VaultFileData>> getFile(String path) => _api.getFile(path);

  Future<ApiResult<VaultPushResult>> pushFile(VaultPushPayload payload) =>
      _api.push(payload);

  String deviceId() => _prefs.getOrCreateDeviceId();

  Future<String> cacheFile(VaultFileData file) async {
    final path = await VaultStorage.writeVaultFile(
      file.vaultPath,
      file.content,
    );
    final hash = VaultStorage.hashOf(file.content);
    await _db.upsertSyncState(
      vaultPath: file.vaultPath,
      localHash: hash,
      syncedHash: file.contentHash,
      status: 'clean',
      baseVersion: file.version,
      localMtime: DateTime.parse(file.serverMtime).millisecondsSinceEpoch,
    );
    return path;
  }

  Future<void> upsertLocalSyncState({
    required String vaultPath,
    required String localHash,
    String? syncedHash,
    required String status,
    int? baseVersion,
    int? localMtime,
  }) async {
    await _db.upsertSyncState(
      vaultPath: vaultPath,
      localHash: localHash,
      syncedHash: syncedHash,
      status: status,
      baseVersion: baseVersion,
      localMtime: localMtime ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, Object?>?> syncStateFor(String vaultPath) =>
      _db.getSyncState(vaultPath);

  Future<void> saveCursor(String? cursor) async {
    await _prefs.setLastCursor(cursor);
    if (cursor != null && cursor.isNotEmpty) {
      await _db.metaSet('lastCursor', cursor);
    }
  }

  String? lastCursor() => _prefs.getLastCursor();

  /// 全表 sync_state 行；传 [status] 时按状态过滤（'dirty'/'conflict'/'clean'）。
  Future<List<Map<String, Object?>>> syncStateRows({String? status}) =>
      _db.listSyncState(status: status);

  /// 阶段九：列出当前用户未解决冲突（含 theirs 内容预览）。
  Future<ApiResult<List<ConflictItem>>> listConflicts() => _api.listConflicts();

  /// 阶段九：解决冲突。
  Future<ApiResult<VaultFileData>> resolveConflict(
    int conflictId,
    ConflictResolvePayload payload,
  ) => _api.resolveConflict(conflictId, payload);

  /// 当天实体同步（docs/09 §9.3）：推送 4 类当天未沉淀实体（LWW）。
  Future<ApiResult<DailyEntitySyncResult>> pushDailyEntities(
    DailyEntityPushPayload payload,
  ) => _api.pushDailyEntities(payload);

  /// 当天实体同步：增量变更（按 updatedAt 游标，含墓碑）。
  Future<ApiResult<DailyEntityChangesData>> getDailyEntityChanges({
    String? since,
    int? limit,
  }) => _api.getDailyEntityChanges(since: since, limit: limit);

  /// sync_meta 读写（实体同步游标等元数据，docs/09 §9.3）。
  Future<String?> getMeta(String key) => _db.metaGet(key);
  Future<void> setMeta(String key, String value) => _db.metaSet(key, value);

  /// 构造一份示例 Daily Markdown（含一条日程 + 一条快速记录）并写入沙盒缓存，
  /// 返回沙盒绝对路径。用于 Step 0 验收闸门 4。
  Future<String> cacheSampleMarkdown() async {
    final today = DateUtil.todayIso();
    final model = DailyDocModel(
      title: DateUtil.dailyTitle(),
      focus: '验证移动端本地缓存',
      schedules: [
        Schedule(
          id: IdUtil.newId(),
          title: '同步联调',
          category: ScheduleCategory.work,
          categoryColor: ScheduleCategory.work.color,
          type: ScheduleType.task,
          startTime: '09:00',
          endTime: '10:00',
          date: today,
          sortOrder: 0,
        ),
      ],
      quickNotes: [
        QuickNote(
          id: IdUtil.newId(),
          date: today,
          content: '移动端首次写入',
          createdAt: '${today}T09:05:00.000',
          updatedAt: '${today}T09:05:00.000',
        ),
      ],
    );
    final md = DailyDocSerializer.serialize(model);
    return VaultStorage.writeDaily(today, md);
  }
}
