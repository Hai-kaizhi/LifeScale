import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/vault_storage.dart';
import '../../vault/data/vault_repository.dart';
import '../../vault/vault_providers.dart';
import '../domain/notes_models.dart';

/// 笔记仓库（开源本地版）：列表 / 读取 / 保存 / 新建，全部本地。
///
/// 数据源为 **本地 Vault Markdown**（单一事实来源）。私有版在此之上叠加
/// 云端 `/api/vault/*` 同步；开源版已移除全部网络调用，笔记仅存于本机。
/// 列表过滤规则（与桌面端 vault 树一致，doc05 §5.2）：
/// - 排除 `Daily/`（每日子目录）
/// - 排除 `Notes/Daily/`（沉淀产物）
/// - 排除 `Reviews/scheme.md`（复盘方案，机器维护）
/// - 仅保留 `.md`
class NotesRepository {
  NotesRepository(this._vaultRepo);

  final VaultRepository _vaultRepo;

  /// 拉取笔记列表（本地已缓存的笔记，按本地修改时间倒序）。
  Future<List<NoteSummary>> listNotes() async {
    final summaries = <NoteSummary>[];
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
            : DateTime.fromMillisecondsSinceEpoch(mtime)
                .toUtc()
                .toIso8601String(),
        version: (row['base_version'] as int?) ?? 0,
        syncedHash: row['synced_hash'] as String?,
      ));
    }
    // 按更新时间倒序。
    summaries.sort((a, b) => b.mtime.compareTo(a.mtime));
    return summaries;
  }

  /// 读取笔记正文（本地）。返回原始 Markdown，缺失返回 null。
  Future<String?> readNote(String vaultPath) async {
    final local = await VaultStorage.readVaultFile(vaultPath);
    if (local != null && local.trim().isNotEmpty) return local;
    return null;
  }

  /// 保存笔记：整文写本地 + 更新本地 sync_state。
  Future<String> saveNote(String vaultPath, String content) async {
    await VaultStorage.writeVaultFile(vaultPath, content);
    final localHash = VaultStorage.hashOf(content);
    final prevState = await _vaultRepo.syncStateFor(vaultPath);
    final syncedHash = prevState?['synced_hash'] as String?;
    await _vaultRepo.upsertLocalSyncState(
      vaultPath: vaultPath,
      localHash: localHash,
      syncedHash: syncedHash,
      status: 'clean',
    );
    return '已保存';
  }

  /// 新建笔记：输入标题 → 落地 `Notes/<title>.md`（命名冲突加后缀）。
  /// 返回新建的 vault 路径。
  Future<String> createNote(String title) async {
    final safeTitle = _sanitizeTitle(title);
    final path = 'Notes/$safeTitle.md';
    final finalPath = await _resolveConflictPath(path);
    final initial = '# $title\n\n';
    await VaultStorage.writeVaultFile(finalPath, initial);
    await _vaultRepo.upsertLocalSyncState(
      vaultPath: finalPath,
      localHash: VaultStorage.hashOf(initial),
      status: 'clean',
    );
    return finalPath;
  }

  // ============================ 内部 ============================

  /// 解析文件名冲突：Notes/foo.md → Notes/foo-1.md …（仅查本地）。
  Future<String> _resolveConflictPath(String basePath) async {
    var candidate = basePath;
    var n = 1;
    while (true) {
      final local = await VaultStorage.readVaultFile(candidate);
      if (local == null) return candidate; // 本地无 → 可用
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
