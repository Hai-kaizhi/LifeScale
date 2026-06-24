import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/auth_bus.dart';
import '../../../core/network/dto/auth_dtos.dart';
import '../auth_providers.dart';
import '../domain/auth_user.dart';
import 'auth_state.dart';

/// 鉴权状态控制器（手写 Riverpod Notifier）。
///
/// 三态语义：
/// - [AuthStatus.local]：无 token / token 失效 / 登出 → 纯本地可用，不请求云端。
/// - [AuthStatus.authenticated]：有有效 token，登录后非阻塞触发设备注册。
/// - 401（非鉴权接口）经 [AuthBus] 派发 → [onAuthExpired] 回到 local。
class AuthController extends Notifier<AuthState> {
  StreamSubscription<void>? _sub;

  @override
  AuthState build() {
    final repo = ref.read(authRepositoryProvider);
    final deviceId = repo.deviceId();

    _sub = AuthBus.instance.expiredStream.listen((_) => onAuthExpired());
    ref.onDispose(() => _sub?.cancel());

    // 异步初始化，先返回 loading 态。
    Future<void>.microtask(_init);
    return AuthState(status: AuthStatus.loading, deviceId: deviceId);
  }

  Future<void> _init() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.loadToken();
    if (!repo.hasToken) {
      state = state.copyWith(status: AuthStatus.local);
      return;
    }
    final saved = repo.savedUser();
    if (saved != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: saved.id,
          username: saved.username,
          email: saved.email,
        ),
        error: null,
      );
    }
    final res = await repo.me();
    if (res is ApiSuccess<CurrentUser>) {
      final u = res.data;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(id: u.id, username: u.username, email: u.email),
        error: null,
      );
    } else if (res is ApiFailure<CurrentUser> && res.code == 401) {
      await repo.clearSession();
      state = state.copyWith(status: AuthStatus.local, user: null);
    } else if (saved == null) {
      state = state.copyWith(status: AuthStatus.local, user: null);
    }
  }

  /// 登录。成功返回 null，失败返回错误信息。
  Future<String?> login(String username, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final res = await repo.login(username, password);
    if (res is ApiSuccess<AuthSession>) {
      final s = res.data;
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(id: s.userId, username: s.username, email: s.email),
        error: null,
      );
      return null;
    }
    final f = res as ApiFailure<AuthSession>;
    state = state.copyWith(error: f.message);
    return f.message;
  }

  /// 注册当前设备，返回原始结果（UI 据此区分成功/失败）。
  Future<ApiResult<DeviceDto>> registerDevice({String? name}) async {
    final repo = ref.read(authRepositoryProvider);
    return repo.registerDevice(state.deviceId ?? repo.deviceId(), name: name);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).clearSession();
    state = state.copyWith(status: AuthStatus.local, user: null);
  }

  /// 401 失效：回到 local 态（保持本地可用，不强制登录）。
  Future<void> onAuthExpired() async {
    await ref.read(authRepositoryProvider).clearSession();
    state = state.copyWith(status: AuthStatus.local, user: null);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final cloudSyncEnabledProvider = Provider<bool>(
  (ref) => ref.watch(
    authControllerProvider.select(
      (state) => state.status == AuthStatus.authenticated,
    ),
  ),
);
