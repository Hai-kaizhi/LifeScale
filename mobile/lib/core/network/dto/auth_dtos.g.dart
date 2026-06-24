// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthSessionImpl _$$AuthSessionImplFromJson(Map<String, dynamic> json) =>
    _$AuthSessionImpl(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      email: json['email'] as String?,
      token: json['token'] as String,
      expiresAt: json['expiresAt'] as String,
    );

Map<String, dynamic> _$$AuthSessionImplToJson(_$AuthSessionImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'email': instance.email,
      'token': instance.token,
      'expiresAt': instance.expiresAt,
    };

_$CurrentUserImpl _$$CurrentUserImplFromJson(Map<String, dynamic> json) =>
    _$CurrentUserImpl(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$$CurrentUserImplToJson(_$CurrentUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
    };

_$DeviceRequestImpl _$$DeviceRequestImplFromJson(Map<String, dynamic> json) =>
    _$DeviceRequestImpl(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String?,
      platform: json['platform'] as String?,
    );

Map<String, dynamic> _$$DeviceRequestImplToJson(_$DeviceRequestImpl instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'name': instance.name,
      'platform': instance.platform,
    };

_$DeviceDtoImpl _$$DeviceDtoImplFromJson(Map<String, dynamic> json) =>
    _$DeviceDtoImpl(
      id: (json['id'] as num?)?.toInt(),
      deviceId: json['deviceId'] as String,
      name: json['name'] as String?,
      platform: json['platform'] as String?,
      lastSyncedAt: json['lastSyncedAt'] as String?,
      lastSeenAt: json['lastSeenAt'] as String?,
    );

Map<String, dynamic> _$$DeviceDtoImplToJson(_$DeviceDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceId': instance.deviceId,
      'name': instance.name,
      'platform': instance.platform,
      'lastSyncedAt': instance.lastSyncedAt,
      'lastSeenAt': instance.lastSeenAt,
    };
