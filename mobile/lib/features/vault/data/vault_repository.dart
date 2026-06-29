import '../../../core/storage/database_service.dart';
import '../../../core/storage/prefs_store.dart';

/// Vault 仓库（开源本地版）：纯本地文件 sync_state 索引。
///
/// 私有版在此之上叠加远端同步（`/api/vault/*`）；开源版已移除全部网络调用，
/// 仅保留本地内容哈希记录与 deviceId，供沉淀/笔记写入路径复用。
class VaultRepository {
  VaultRepository(this._db, this._prefs);

  final DatabaseService _db;
  final PrefsStore _prefs;

  String deviceId() => _prefs.getOrCreateDeviceId();

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

  /// 全表 sync_state 行；传 [status] 时按状态过滤（'dirty'/'conflict'/'clean'）。
  Future<List<Map<String, Object?>>> syncStateRows({String? status}) =>
      _db.listSyncState(status: status);
}
