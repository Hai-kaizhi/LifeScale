import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dto/vault_dtos.dart';
import '../../../core/storage/vault_storage.dart';
import '../../vault/data/vault_repository.dart';
import '../../vault/vault_providers.dart';
import '../domain/notes_models.dart';

/// 笔记仓库：列表（云端摘要 + 本地同步状态）/ 读取 / 保存（读-写-推送）/ 新建。
///
/// 数据源为 **Vault Markdown**（单一事实来源），同步走 `/api/vault/*`。
/// 列表过滤规则（与桌面端 vault 树一致，doc05 §5.2）：
/// - 排除 `Daily/`（每日子目录）
/// - 排除 `Reviews/scheme.md`（复盘方案，机器维护）
/// - 排除 `.conflict-*.md`（冲突副本，交桌面端处理）
/// - 仅保留 `.md`
class NotesRepository {
  NotesRepository(this._vaultRepo);

  final VaultRepository _vaultRepo;

  /// 拉取笔记列表（云端全量摘要 + 本地同步状态）。
  Future<List<NoteSummary>> listNotes() async {
    final changesRes = await _vaultRepo.changes();
    final summaries = <NoteSummary>[];
    switch (changesRes) {
      case ApiSuccess(:final data):
        for (final c in data.changes) {
          if (c.status == 'deleted') continue;
          if (!_isNote(c.vaultPath)) continue;
          // 本地 sync_state：判断是否已同步、最新版本。
          final localState = await _vaultRepo.syncStateFor(c.vaultPath);
          final syncedHash = localState?['synced_hash'] as String?;
          summaries.add(NoteSummary(
            vaultPath: c.vaultPath,
            title: _titleOf(c.vaultPath),
            mtime: c.serverMtime,
            version: c.version,
            syncedHash: syncedHash,
          ));
        }
      case ApiFailure():
        // 离线：仅本地已缓存笔记。
        final rows = await _vaultRepo.syncStateRows();
        for (final row in rows) {
          final path = row['vault_path'] as String?;
          if (path == null || !_isNote(path)) continue;
          final mtime = row['local_mtime'] as int?;
          summaries.add(NoteSummary(
            vaultPath: path,
            title: _titleOf(path),
            mtime: mtime == null
                ? ''
                : DateTime.fromMillisecondsSinceEpoch(mtime).toUtc().toIso8601String(),
            version: (row['base_version'] as int?) ?? 0,
            syncedHash: row['synced_hash'] as String?,
          ));
        }
    }
    // 按更新时间倒序。
    summaries.sort((a, b) => b.mtime.compareTo(a.mtime));
    return summaries;
  }

  /// 读取笔记正文（本地优先 → 云端）。返回原始 Markdown，缺失返回 null。
  Future<String?> readNote(String vaultPath) async {
    final local = await VaultStorage.readVaultFile(vaultPath);
    if (local != null && local.trim().isNotEmpty) return local;
    final res = await _vaultRepo.getFile(vaultPath);
    switch (res) {
      case ApiSuccess(:final data):
        await _vaultRepo.cacheFile(data);
        return data.content;
      case ApiFailure():
        return null;
    }
  }

  /// 保存笔记（读-写-推送）：整文写本地 + 标 dirty + PUT。
  /// 与沉淀服务同款的乐观锁 + 冲突处理。
  Future<String> saveNote(String vaultPath, String content) async {
    // 落本地。
    await VaultStorage.writeVaultFile(vaultPath, content);
    final localHash = VaultStorage.hashOf(content);
    final prevState = await _vaultRepo.syncStateFor(vaultPath);
    final syncedHash = prevState?['synced_hash'] as String?;
    final baseVersion = prevState?['base_version'] as int?;
    await _vaultRepo.upsertLocalSyncState(
      vaultPath: vaultPath,
      localHash: localHash,
      syncedHash: syncedHash,
      status: 'dirty',
      baseVersion: baseVersion,
    );
    // 推送。
    final outcome = await _push(vaultPath, content, syncedHash, baseVersion);
    return outcome;
  }

  /// 新建笔记：输入标题 → 落地 `Notes/<title>.md`（命名冲突加后缀）。
  /// 返回新建的 vault 路径。
  Future<String> createNote(String title) async {
    final safeTitle = _sanitizeTitle(title);
    final path = 'Notes/$safeTitle.md';
    // 冲突检测：本地已有或云端已有则加序号。
    final finalPath = await _resolveConflictPath(path);
    final initial = '# $title\n\n';
    await VaultStorage.writeVaultFile(finalPath, initial);
    await _vaultRepo.upsertLocalSyncState(
      vaultPath: finalPath,
      localHash: VaultStorage.hashOf(initial),
      status: 'dirty',
    );
    await _push(finalPath, initial, null, null);
    return finalPath;
  }

  // ============================ 内部 ============================

  Future<String> _push(
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
          return '冲突：已保留双方副本，建议回桌面端处理';
        } else {
          await _vaultRepo.upsertLocalSyncState(
            vaultPath: path,
            localHash: VaultStorage.hashOf(content),
            syncedHash: data.data?.contentHash,
            status: 'clean',
            baseVersion: data.data?.version ?? baseVersion,
          );
          return '已保存并同步';
        }
      case ApiFailure():
        // 网络失败：保持 dirty。
        debugPrint('⚠️ 笔记推送失败，已留 dirty 待重推：$path');
        return '已保存到本地，待同步';
    }
  }

  /// 解析文件名冲突：Notes/foo.md → Notes/foo-1.md …
  Future<String> _resolveConflictPath(String basePath) async {
    var candidate = basePath;
    var n = 1;
    while (true) {
      final local = await VaultStorage.readVaultFile(candidate);
      if (local == null) {
        // 进一步查云端是否已存在。
        final res = await _vaultRepo.getFile(candidate);
        switch (res) {
          case ApiFailure():
            return candidate; // 云端也无 → 可用
          case ApiSuccess(:final data):
            // 云端已有 → 缓存它并改名。
            await _vaultRepo.cacheFile(data);
        }
      }
      final dot = basePath.lastIndexOf('.');
      final stem = dot > 0 ? basePath.substring(0, dot) : basePath;
      final ext = dot > 0 ? basePath.substring(dot) : '';
      candidate = '$stem-$n$ext';
      n++;
    }
  }

  bool _isNote(String vaultPath) {
    if (!vaultPath.toLowerCase().endsWith('.md')) return false;
    // 排除 Daily/（历史遗留当天文档）与 Notes/Daily/（沉淀产物，docs/09 §6.1.3）。
    if (vaultPath.startsWith('Daily/')) return false;
    if (vaultPath.startsWith('Notes/Daily/')) return false;
    if (vaultPath == 'Reviews/scheme.md') return false;
    if (vaultPath.contains('.conflict-')) return false;
    return true;
  }

  String _titleOf(String vaultPath) {
    final name = vaultPath.split('/').last;
    return name.toLowerCase().endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
  }

  String _sanitizeTitle(String title) {
    // 去除文件名非法字符。
    var t = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (t.isEmpty) t = '未命名';
    // 限制长度。
    if (t.length > 60) t = t.substring(0, 60);
    return t;
  }
}

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(vaultRepositoryProvider)),
);
