import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_dtos.freezed.dart';
part 'auth_dtos.g.dart';

/// 登录/注册成功返回的会话（`POST /auth/login`、`POST /auth/register` 的 data）。
/// 注意：用户标识字段名为 `userId`（区别于 [CurrentUser.id]）。
@freezed
class AuthSession with _$AuthSession {
  const factory AuthSession({
    required int userId,
    required String username,
    String? email,
    required String token,
    required String expiresAt,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}

/// `GET /auth/me` 的 data。用户标识字段名为 `id`（与 [AuthSession.userId] 不同）。
@freezed
class CurrentUser with _$CurrentUser {
  const factory CurrentUser({
    required int id,
    required String username,
    String? email,
  }) = _CurrentUser;

  factory CurrentUser.fromJson(Map<String, dynamic> json) =>
      _$CurrentUserFromJson(json);
}

/// `POST /auth/devices` 请求体。
@freezed
class DeviceRequest with _$DeviceRequest {
  const factory DeviceRequest({
    required String deviceId,
    String? name,
    String? platform,
  }) = _DeviceRequest;

  factory DeviceRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceRequestFromJson(json);
}

/// 设备信息（注册返回与列表项）。
@freezed
class DeviceDto with _$DeviceDto {
  const factory DeviceDto({
    int? id,
    required String deviceId,
    String? name,
    String? platform,
    String? lastSyncedAt,
    String? lastSeenAt,
  }) = _DeviceDto;

  factory DeviceDto.fromJson(Map<String, dynamic> json) =>
      _$DeviceDtoFromJson(json);
}
