import 'dart:async';

/// 鉴权失效事件总线（core 内单例）。
///
/// 把「HTTP 401」这一网络层事件与「AuthController 回到 local 态」这一表现层动作解耦：
/// [ResponseInterceptor] 仅 `AuthBus.instance.expired()`，AuthController 订阅 stream。
/// 避免网络层反向依赖 features/auth。
class AuthBus {
  AuthBus._();
  static final AuthBus instance = AuthBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get expiredStream => _controller.stream;

  void expired() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
