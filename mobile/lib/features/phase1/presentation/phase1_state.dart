import '../domain/phase1_models.dart';

enum Phase1Stage { booting, login, syncing, ready }

class Phase1State {
  const Phase1State({
    this.stage = Phase1Stage.booting,
    this.bootComplete = false,
    this.loginPending = false,
    this.syncPending = false,
    this.error,
    this.info,
    this.steps = defaultSteps,
    this.summary = const SyncSummary(),
    this.preview,
  });

  final Phase1Stage stage;
  final bool bootComplete;
  final bool loginPending;
  final bool syncPending;
  final String? error;
  final String? info;
  final List<SyncStepView> steps;
  final SyncSummary summary;
  final TodayPreview? preview;

  // 注意：tone 字段已移除。时段色调真相统一由 ThemeController 管理
  // （lib/core/theme/theme_controller.dart），不再在 Phase1State 重复持有。

  static const defaultSteps = [
    SyncStepView(
      id: 'device',
      title: '注册当前设备',
      description: '建立这台手机与云端 Vault 的同步关系',
    ),
    SyncStepView(
      id: 'changes',
      title: '拉取云端 Daily',
      description: '读取云端变更摘要并下载必要 Markdown',
    ),
    SyncStepView(
      id: 'cache',
      title: '初始化本地缓存',
      description: '写入 App 沙盒并更新 sync_state',
    ),
  ];

  Phase1State copyWith({
    Phase1Stage? stage,
    bool? bootComplete,
    bool? loginPending,
    bool? syncPending,
    String? error,
    bool clearError = false,
    String? info,
    bool clearInfo = false,
    List<SyncStepView>? steps,
    SyncSummary? summary,
    TodayPreview? preview,
  }) => Phase1State(
    stage: stage ?? this.stage,
    bootComplete: bootComplete ?? this.bootComplete,
    loginPending: loginPending ?? this.loginPending,
    syncPending: syncPending ?? this.syncPending,
    error: clearError ? null : error ?? this.error,
    info: clearInfo ? null : info ?? this.info,
    steps: steps ?? this.steps,
    summary: summary ?? this.summary,
    preview: preview ?? this.preview,
  );
}
