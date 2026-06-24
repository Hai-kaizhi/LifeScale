import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT token 持久化（Android Keystore）。
///
/// 维护内存缓存以供 dio 拦截器同步读取（`onRequest` 非异步）。
/// bootstrap 阶段调 [load] 预热；登录调 [write]；登出/失效调 [clear]。
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'lifescale.auth.token';

  final FlutterSecureStorage _storage;
  String? _cached;

  bool get hasToken => _cached != null && _cached!.isNotEmpty;
  String? get token => _cached;

  Future<void> load() async {
    _cached = await _storage.read(key: _key);
  }

  Future<void> write(String token) async {
    _cached = token;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }
}

class MemorySecureTokenStore extends SecureTokenStore {
  String? _token;

  @override
  bool get hasToken => _token != null && _token!.isNotEmpty;

  @override
  String? get token => _token;

  @override
  Future<void> load() async {}

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}
