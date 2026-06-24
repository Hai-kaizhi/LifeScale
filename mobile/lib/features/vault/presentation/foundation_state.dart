import 'package:freezed_annotation/freezed_annotation.dart';

part 'foundation_state.freezed.dart';

/// Smoke 页（第 0 步验收）的交互结果状态。
@freezed
class FoundationState with _$FoundationState {
  const factory FoundationState({
    @Default('') String loginMessage,
    @Default('') String deviceMessage,
    @Default('') String changesMessage,
    @Default('') String cacheMessage,
    @Default(false) bool busy,
  }) = _FoundationState;
}
