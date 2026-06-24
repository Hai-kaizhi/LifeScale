import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vault/vault_providers.dart';

/// 全局同步状态（阶段九）：聚合 sync_state 的 dirty/conflict 计数，
/// 供 MinePage / AppShell 展示「待同步 N 条 / 冲突 M 条」。
class SyncStatusState {
  const SyncStatusState({
    this.pendingCount = 0,
    this.conflictCount = 0,
    this.lastSyncAt,
    this.syncing = false,
  });

  final int pendingCount; // status='dirty'
  final int conflictCount; // status='conflict'
  final DateTime? lastSyncAt;
  final bool syncing;

  bool get hasPending => pendingCount > 0;
  bool get hasConflict => conflictCount > 0;

  SyncStatusState copyWith({
    int? pendingCount,
    int? conflictCount,
    DateTime? lastSyncAt,
    bool? syncing,
  }) =>
      SyncStatusState(
        pendingCount: pendingCount ?? this.pendingCount,
        conflictCount: conflictCount ?? this.conflictCount,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        syncing: syncing ?? this.syncing,
      );
}

class SyncStatusController extends Notifier<SyncStatusState> {
  @override
  SyncStatusState build() {
    // 首帧后异步刷新一次。
    Future<void>.microtask(refresh);
    return const SyncStatusState();
  }

  /// 重新聚合 sync_state 计数。flush 前后、进入 MinePage、解决冲突后调用。
  Future<void> refresh() async {
    final repo = ref.read(vaultRepositoryProvider);
    final dirty = await repo.syncStateRows(status: 'dirty');
    final conflict = await repo.syncStateRows(status: 'conflict');
    state = state.copyWith(
      pendingCount: dirty.length,
      conflictCount: conflict.length,
    );
  }

  void setSyncing(bool syncing) =>
      state = state.copyWith(syncing: syncing, lastSyncAt: DateTime.now());
}

final syncStatusControllerProvider =
    NotifierProvider<SyncStatusController, SyncStatusState>(
        SyncStatusController.new);
