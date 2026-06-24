import '../../../core/network/api_result.dart';
import '../../../core/network/dto/auth_dtos.dart';
import '../../../core/storage/prefs_store.dart';
import '../../../core/storage/secure_token_store.dart';
import 'auth_api.dart';

/// 鉴权仓库：组合远程数据源 + 本地持久化（token / 用户摘要 / deviceId）。
class AuthRepository {
  AuthRepository(this._api, this._tokenStore, this._prefs);

  final AuthApi _api;
  final SecureTokenStore _tokenStore;
  final PrefsStore _prefs;

  bool get hasToken => _tokenStore.hasToken;

  /// 启动预热：把 Keystore 中的 token 读入内存缓存（供 dio 拦截器同步读取）。
  Future<void> loadToken() => _tokenStore.load();

  String deviceId() => _prefs.getOrCreateDeviceId();
  UserSummary? savedUser() => _prefs.getUser();

  Future<ApiResult<AuthSession>> login(String username, String password) async {
    final res = await _api.login(username, password);
    if (res is ApiSuccess<AuthSession>) {
      final s = res.data;
      await _tokenStore.write(s.token);
      await _prefs.setUser(
        UserSummary(id: s.userId, username: s.username, email: s.email),
      );
    }
    return res;
  }

  Future<ApiResult<CurrentUser>> me() => _api.me();

  Future<ApiResult<DeviceDto>> registerDevice(
    String deviceId, {
    String? name,
    String platform = 'android',
  }) => _api.registerDevice(
    DeviceRequest(deviceId: deviceId, name: name, platform: platform),
  );

  Future<void> clearSession() async {
    await _tokenStore.clear();
    await _prefs.clearUser();
  }
}
