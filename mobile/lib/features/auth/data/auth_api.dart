import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dto/auth_dtos.dart';

/// 鉴权远程数据源（`/api/auth`）。
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<ApiResult<AuthSession>> login(String username, String password) =>
      _client.post(
        ApiEndpoints.authLogin,
        body: {'username': username, 'password': password},
        fromJsonT: (j) => AuthSession.fromJson(j as Map<String, dynamic>),
      );

  Future<ApiResult<CurrentUser>> me() => _client.get(
    ApiEndpoints.authMe,
    fromJsonT: (j) => CurrentUser.fromJson(j as Map<String, dynamic>),
  );

  Future<ApiResult<DeviceDto>> registerDevice(DeviceRequest req) =>
      _client.post(
        ApiEndpoints.authDevices,
        body: req.toJson(),
        fromJsonT: (j) => DeviceDto.fromJson(j as Map<String, dynamic>),
      );

  Future<ApiResult<List<DeviceDto>>> listDevices() => _client.get(
    ApiEndpoints.authDevices,
    fromJsonT: (j) => (j as List)
        .map((e) => DeviceDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
