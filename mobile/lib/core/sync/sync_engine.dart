import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_result.dart';
import '../network/dto/vault_dtos.dart';
import '../storage/vault_storage.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../features/vault/vault_providers.dart';
import 'daily_entity_sync.dart';

/// 补推引擎（阶段九核心）：扫描本地 sync_state 中 status='dirty' 的记录，
/// 逐条读本地内容 → 重新 PUT（乐观锁）→ 按 outcome 标 clean/conflict/保持dirty。
/// 末尾追加当天实体同步（docs/09 §9.3，settled=0 才同步）。
///
/// 触发时机（由调用方接入）：
/// - 启动后（[Phase1Controller.runInitialSync] 末尾）
/// - 网络恢复（[ConnectivityController] offline→online）
/// - 回前台（[AppShell] WidgetsBindingObserver resumed）
/// - 手动（MinePage「立即同步」）
///
/// 设计：幂等、串行（内部锁防并发 flush + 用户新编辑竞态）、失败静默留 dirty。
class SyncEngine {
  SyncEngine(this._vaultRepo, this._entitySync);

  final VaultRepository _vaultRepo;
  final DailyEntitySync _entitySync;
  bool _flushing = false;

  /// 是否正在补推（供 UI 防抖）。
  bool get isFlushing => _flushing;

  /// 补推所有 dirty 记录。返回 [SyncFlushResult] 统计。
  Future<SyncFlushResult> flushPending() async {
    if (_flushing) {
      // 已在补推中，跳过本次（防抖）。
      return const SyncFlushResult(skipped: true);
    }
    _flushing = true;
    int pushed = 0;
    int conflicts = 0;
    int failed = 0;
    try {
      final dirtyRows = await _vaultRepo.syncStateRows(status: 'dirty');
      for (final row in dirtyRows) {
        final path = row['vault_path'] as String?;
        if (path == null) continue;
        final syncedHash = row['synced_hash'] as String?;
        final baseVersion = row['base_version'];
        final baseVersionInt = baseVersion is int
            ? baseVersion
            : (baseVersion is num ? baseVersion.toInt() : null);
        final content = await VaultStorage.readVaultFile(path);
        if (content == null) {
          // 本地文件丢失（被删？），无法补推，跳过。
          failed += 1;
          continue;
        }
        final outcome = await _pushOne(path, content, syncedHash, baseVersionInt);
        switch (outcome) {
          case _PushOutcome.clean:
            pushed += 1;
          case _PushOutcome.conflict:
            conflicts += 1;
          case _PushOutcome.failed:
            failed += 1;
        }
      }
      // 当天未沉淀实体同步（docs/09 §9.3，LWW；settled=0 才同步，沉淀后转文件同步）。
      try {
        await _entitySync.syncOnce();
      } catch (e) {
        debugPrint('⚠️ 实体同步异常：$e');
      }
    } catch (e) {
      debugPrint('⚠️ flushPending 异常：$e');
    } finally {
      _flushing = false;
    }
    return SyncFlushResult(pushed: pushed, conflicts: conflicts, failed: failed);
  }

  /// 推送单条并更新 sync_state（逻辑与 DailyMutationService._tryPush / NotesRepository._push 同形）。
  Future<_PushOutcome> _pushOne(
    String path,
    String content,
    String? syncedHash,
    int? baseVersion,
  ) async {
    final payload = VaultPushPayload(
      vaultPath: path,
      content: content,
      ifMatchHash: syncedHash,
      deviceId: _vaultRepo.deviceId(),
    );
    final res = await _vaultRepo.pushFile(payload);
    switch (res) {
      case ApiSuccess(:final data):
        if (data.outcome == 'conflict') {
          await _vaultRepo.upsertLocalSyncState(
            vaultPath: path,
            localHash: VaultStorage.hashOf(content),
            syncedHash: data.conflict?.theirsHash,
            status: 'conflict',
            baseVersion: baseVersion,
          );
          return _PushOutcome.conflict;
        }
        // created/ok/merged → clean。
        await _vaultRepo.upsertLocalSyncState(
          vaultPath: path,
          localHash: VaultStorage.hashOf(content),
          syncedHash: data.data?.contentHash,
          status: 'clean',
          baseVersion: data.data?.version ?? baseVersion,
        );
        return _PushOutcome.clean;
      case ApiFailure():
        // 网络失败：保持 dirty，下次触发重试。
        debugPrint('⚠️ 补推失败，保持 dirty：$path');
        return _PushOutcome.failed;
    }
  }
}

/// 单条推送结果。
enum _PushOutcome { clean, conflict, failed }

/// 补推统计。
class SyncFlushResult {
  const SyncFlushResult({
    this.pushed = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.skipped = false,
  });

  final int pushed;
  final int conflicts;
  final int failed;
  final bool skipped;

  bool get hadActivity => pushed > 0 || conflicts > 0;
}

/// Provider：依赖 VaultRepository + DailyEntitySync。
final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    ref.watch(vaultRepositoryProvider),
    ref.watch(dailyEntitySyncProvider),
  ),
);
