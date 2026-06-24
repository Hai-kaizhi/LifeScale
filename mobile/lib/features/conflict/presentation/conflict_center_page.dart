import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dto/vault_dtos.dart';
import '../../../core/storage/vault_storage.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../../core/theme/theme_providers.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';
import '../../vault/vault_providers.dart';

/// 冲突中心页（阶段九）：列出未解决冲突，提供「保留本机 / 保留云端 / 稍后处理」。
///
/// 数据来自云端 `GET /vault/conflicts`（含 theirs 内容预览）；本机内容从沙盒缓存读取。
/// 解决后刷新列表 + 同步状态计数。不做三栏逐行合并（文档明确不做）。
class ConflictCenterPage extends ConsumerStatefulWidget {
  const ConflictCenterPage({super.key});

  @override
  ConsumerState<ConflictCenterPage> createState() => _ConflictCenterPageState();
}

class _ConflictCenterPageState extends ConsumerState<ConflictCenterPage> {
  List<ConflictItem> _conflicts = [];
  final Map<String, String> _mineContents = {}; // vaultPath → 本机内容
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(vaultRepositoryProvider);
    final res = await repo.listConflicts();
    switch (res) {
      case ApiSuccess(:final data):
        final mineMap = <String, String>{};
        for (final c in data) {
          final local = await VaultStorage.readVaultFile(c.vaultPath);
          mineMap[c.vaultPath] = local ?? '（本地无内容）';
        }
        if (!mounted) return;
        setState(() {
          _conflicts = data;
          _mineContents
            ..clear()
            ..addAll(mineMap);
          _loading = false;
        });
      case ApiFailure(:final message):
        if (!mounted) return;
        setState(() {
          _error = message;
          _loading = false;
        });
    }
  }

  Future<void> _resolveKeepMine(ConflictItem c) async {
    final mine = _mineContents[c.vaultPath] ?? '';
    final repo = ref.read(vaultRepositoryProvider);
    final res = await repo.resolveConflict(
      c.conflictId,
      ConflictResolvePayload(strategy: 'keepMine', content: mine),
    );
    if (!mounted) return;
    switch (res) {
      case ApiSuccess(:final data):
        // 本机已覆盖正本：更新本地 sync_state 为 clean。
        await repo.upsertLocalSyncState(
          vaultPath: c.vaultPath,
          localHash: VaultStorage.hashOf(mine),
          syncedHash: data.contentHash,
          status: 'clean',
          baseVersion: data.version,
        );
        _toast('已保留本机版本');
      case ApiFailure(:final message):
        _toast('解决失败：$message');
        return;
    }
    await _afterResolve();
  }

  Future<void> _resolveKeepTheirs(ConflictItem c) async {
    final repo = ref.read(vaultRepositoryProvider);
    // 先 resolve（服务端标记 resolved）。
    await repo.resolveConflict(
      c.conflictId,
      const ConflictResolvePayload(strategy: 'keepTheirs'),
    );
    // 再拉云端正本覆盖本地 + 标 clean。
    final fileRes = await repo.getFile(c.vaultPath);
    if (!mounted) return;
    switch (fileRes) {
      case ApiSuccess(:final data):
        await repo.cacheFile(data);
        _toast('已保留云端版本');
      case ApiFailure():
        // 仍标 clean（冲突已解决），本地保留现状。
        await repo.upsertLocalSyncState(
          vaultPath: c.vaultPath,
          localHash: VaultStorage.hashOf(
              _mineContents[c.vaultPath] ?? ''),
          status: 'clean',
        );
    }
    await _afterResolve();
  }

  Future<void> _afterResolve() async {
    await ref.read(syncStatusControllerProvider.notifier).refresh();
    await _load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: tokens.text,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '冲突处理',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    color: tokens.muted,
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(tokens, tone)),
        ],
      ),
    );
  }

  Widget _body(Phase1ToneTokens tokens, TodayTone tone) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 40, color: tokens.muted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.muted, fontSize: 14)),
            ],
          ),
        ),
      );
    }
    if (_conflicts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 44, color: tokens.success),
              const SizedBox(height: 12),
              Text('没有未解决的冲突',
                  style: TextStyle(color: tokens.text, fontSize: 16)),
              const SizedBox(height: 6),
              Text('所有文件已是最新',
                  style: TextStyle(color: tokens.muted, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: tokens.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        itemCount: _conflicts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) =>
            _conflictCard(_conflicts[i], tokens, tone),
      ),
    );
  }

  Widget _conflictCard(ConflictItem c, Phase1ToneTokens tokens, TodayTone tone) {
    final mine = _mineContents[c.vaultPath] ?? '（本地无内容）';
    final theirs = c.theirsContent.isEmpty ? '（云端无内容）' : c.theirsContent;
    return GlassPanel(
      tone: tone,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: tokens.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.vaultPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sidePreview(tokens, '本机版本', mine, tokens.primary),
          const SizedBox(height: 8),
          _sidePreview(tokens, '云端版本', theirs, tokens.secondary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  tokens,
                  label: '保留本机',
                  color: tokens.primary,
                  onTap: () => _resolveKeepMine(c),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  tokens,
                  label: '保留云端',
                  color: tokens.secondary,
                  onTap: () => _resolveKeepTheirs(c),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidePreview(
      Phase1ToneTokens tokens, String label, String content, Color accent) {
    final preview = content.length > 120
        ? '${content.substring(0, 120)}…'
        : content;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(preview,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: tokens.text, fontSize: 12, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _actionButton(
    Phase1ToneTokens tokens, {
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
