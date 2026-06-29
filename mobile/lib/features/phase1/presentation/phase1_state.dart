import '../domain/phase1_models.dart';

/// 启动阶段（开源本地版）：仅 booting → ready 两态。
/// 私有版的 login/syncing 阶段随网络/同步层一并移除。
enum Phase1Stage { booting, ready }

class Phase1State {
  const Phase1State({
    this.stage = Phase1Stage.booting,
    this.bootComplete = false,
    this.error,
    this.info,
    this.summary = const SyncSummary(),
    this.preview,
  });

  final Phase1Stage stage;
  final bool bootComplete;
  final String? error;
  final String? info;
  final SyncSummary summary;
  final TodayPreview? preview;

  Phase1State copyWith({
    Phase1Stage? stage,
    bool? bootComplete,
    String? error,
    bool clearError = false,
    String? info,
    bool clearInfo = false,
    SyncSummary? summary,
    TodayPreview? preview,
  }) => Phase1State(
    stage: stage ?? this.stage,
    bootComplete: bootComplete ?? this.bootComplete,
    error: clearError ? null : error ?? this.error,
    info: clearInfo ? null : info ?? this.info,
    summary: summary ?? this.summary,
    preview: preview ?? this.preview,
  );
}
