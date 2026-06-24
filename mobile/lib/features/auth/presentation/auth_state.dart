import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/auth_user.dart';

part 'auth_state.freezed.dart';

/// 鉴权三态（与桌面端 `useAuth` 的 loading/local/authenticated 对齐）。
enum AuthStatus { loading, local, authenticated }

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(AuthStatus.loading) AuthStatus status,
    AuthUser? user,
    String? deviceId,
    String? error,
  }) = _AuthState;
}
