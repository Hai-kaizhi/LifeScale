import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dto/vault_dtos.dart';
import '../../../core/storage/vault_storage.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/util/date_util.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../daily_markdown/data/daily_doc_parser.dart';
import '../../review/data/review_precipitate_service.dart';
import '../../vault/vault_providers.dart';
import '../domain/phase1_models.dart';
import 'phase1_state.dart';

class Phase1Controller extends Notifier<Phase1State> {
  @override
  Phase1State build() {
    Future<void>.microtask(completeBoot);
    return const Phase1State();
  }

  Future<void> completeBoot() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final cached = await _loadCachedPreview(
      summary: const SyncSummary(offline: true),
    );
    state = state.copyWith(
      bootComplete: true,
      stage: Phase1Stage.ready,
      preview: cached,
      summary: cached?.syncSummary ?? const SyncSummary(offline: true),
    );
  }

  Future<void> loginAndSync(String username, String password) async {
    state = state.copyWith(
      loginPending: true,
      stage: Phase1Stage.login,
      clearError: true,
      clearInfo: true,
    );

    final err = await ref
        .read(authControllerProvider.notifier)
        .login(username, password);
    if (err != null) {
      final fallback = await _loadCachedPreview(
        summary: const SyncSummary(offline: true),
      );
      final lowerErr = err.toLowerCase();
      if (fallback != null &&
          (lowerErr.contains('network') ||
              lowerErr.contains('offline') ||
              lowerErr.contains('connection'))) {
        state = state.copyWith(
          loginPending: false,
          stage: Phase1Stage.ready,
          preview: fallback,
          summary: fallback.syncSummary,
          error: '网络不可用，已展示最近缓存',
        );
        return;
      }
      state = state.copyWith(
        loginPending: false,
        error: err,
        info: '可使用 mock 账号 lifescale / 任意密码继续验证',
      );
      return;
    }

    state = state.copyWith(loginPending: false, stage: Phase1Stage.syncing);
    await runInitialSync();
  }

  Future<void> runInitialSync() async {
    state = state.copyWith(
      syncPending: true,
      stage: Phase1Stage.syncing,
      steps: Phase1State.defaultSteps,
      summary: const SyncSummary(),
      clearError: true,
      clearInfo: true,
    );

    var cachedFiles = 0;
    var failedFiles = 0;
    String? cursor;
    String? deviceId;
    String? deviceName;

    try {
      _markStep('device', SyncStepStatus.running);
      final deviceResult = await ref
          .read(authControllerProvider.notifier)
          .registerDevice(name: 'LifeScale Mobile');
      switch (deviceResult) {
        case ApiSuccess(:final data):
          deviceId = data.deviceId;
          deviceName = data.name ?? 'LifeScale Mobile';
          _markStep('device', SyncStepStatus.success, '设备已加入同步列表');
        case ApiFailure(:final message):
          _markStep('device', SyncStepStatus.error, message);
          throw _Phase1SyncException(message);
      }

      _markStep('changes', SyncStepStatus.running);
      final repo = ref.read(vaultRepositoryProvider);
      final changesResult = await repo.changes(
        since: repo.lastCursor(),
        limit: 20,
      );
      late final VaultChangesData changes;
      switch (changesResult) {
        case ApiSuccess(:final data):
          changes = data;
          cursor = data.nextCursor;
          _markStep(
            'changes',
            SyncStepStatus.success,
            '发现 ${data.changes.length} 条云端变更',
          );
        case ApiFailure(:final message):
          _markStep('changes', SyncStepStatus.error, message);
          throw _Phase1SyncException(message);
      }

      _markStep('cache', SyncStepStatus.running);
      for (final change in changes.changes.where(
        (item) => item.status != 'deleted',
      )) {
        final fileResult = await repo.getFile(change.vaultPath);
        switch (fileResult) {
          case ApiSuccess(:final data):
            await repo.cacheFile(data);
            cachedFiles += 1;
          case ApiFailure():
            failedFiles += 1;
        }
      }
      await repo.saveCursor(cursor);

      // 阶段九：启动补推 —— 把重启前残留的 dirty 记录（断网期间累积）自动重推。
      try {
        await ref.read(syncEngineProvider).flushPending();
        await ref.read(syncStatusControllerProvider.notifier).refresh();
      } catch (_) {
        // 补推失败不影响启动流程，下次网络恢复/回前台再试。
      }

      // docs/09 §7.3 惰性补沉淀：扫描「过去日期且未沉淀」的记录逐个沉淀（fire-and-forget）。
      try {
        await ref.read(reviewPrecipitateServiceProvider).lazyBackfillOnAppOpen();
      } catch (_) {
        // 补沉淀失败不影响启动流程。
      }

      _markStep(
        'cache',
        failedFiles == 0 ? SyncStepStatus.success : SyncStepStatus.error,
        failedFiles == 0
            ? '已缓存 $cachedFiles 个文件'
            : '已缓存 $cachedFiles 个文件，$failedFiles 个失败',
      );

      final summary = SyncSummary(
        deviceId: deviceId,
        deviceName: deviceName,
        changes: changes.changes.length,
        cachedFiles: cachedFiles,
        failedFiles: failedFiles,
        cursor: cursor,
      );
      final preview = await _loadCachedPreview(summary: summary);
      state = state.copyWith(
        syncPending: false,
        stage: Phase1Stage.ready,
        summary: summary,
        preview: preview,
        info: failedFiles == 0 ? '同步初始化完成' : '部分文件失败，已保留可用缓存',
      );
    } catch (e) {
      final fallback = await _loadCachedPreview(
        summary: SyncSummary(
          deviceId: deviceId,
          deviceName: deviceName,
          changes: 0,
          cachedFiles: cachedFiles,
          failedFiles: failedFiles,
          cursor: cursor,
          offline: true,
        ),
      );
      if (fallback != null) {
        state = state.copyWith(
          syncPending: false,
          stage: Phase1Stage.ready,
          preview: fallback,
          summary: fallback.syncSummary,
          error: '网络不可用，已展示最近缓存',
        );
        return;
      }
      state = state.copyWith(
        syncPending: false,
        stage: Phase1Stage.ready,
        error: e is _Phase1SyncException ? e.message : '$e',
        summary: const SyncSummary(offline: true),
      );
    }
  }

  /// 切换时段色调：转发到全局 [ThemeController]（单一真相）。
  void setTone(AppTone tone) {
    ref.read(themeControllerProvider.notifier).setTone(tone);
  }

  void showFutureFeature(String label) {
    state = state.copyWith(info: '$label 当前阶段暂未开发', clearError: true);
  }

  void clearTransient() {
    state = state.copyWith(clearInfo: true, clearError: true);
  }

  void _markStep(String id, SyncStepStatus status, [String? message]) {
    state = state.copyWith(
      steps: [
        for (final step in state.steps)
          if (step.id == id)
            step.copyWith(status: status, message: message)
          else
            step,
      ],
    );
  }

  Future<TodayPreview?> _loadCachedPreview({
    required SyncSummary summary,
  }) async {
    final date = DateUtil.todayIso();
    final md = await VaultStorage.readDaily(date);
    if (md == null) return null;
    final parsed = DailyDocParser.parse(md, date: date);
    return TodayPreview(
      date: date,
      title: parsed.model.title.isEmpty
          ? DateUtil.dailyTitle()
          : parsed.model.title,
      model: parsed.model,
      cachedPath: VaultStorage.resolveVaultPath('Daily/$date.md'),
      syncSummary: summary,
    );
  }

  // _toneForNow() 已移除：时段判定统一收敛到 ToneTheme.toneForNow()，
  // tone 状态由 ThemeController 持有。
}

class _Phase1SyncException implements Exception {
  const _Phase1SyncException(this.message);
  final String message;
}

final phase1ControllerProvider =
    NotifierProvider<Phase1Controller, Phase1State>(Phase1Controller.new);
