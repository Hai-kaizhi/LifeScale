// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) {
  return _AuthSession.fromJson(json);
}

/// @nodoc
mixin _$AuthSession {
  int get userId => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  String get expiresAt => throw _privateConstructorUsedError;

  /// Serializes this AuthSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AuthSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthSessionCopyWith<AuthSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthSessionCopyWith<$Res> {
  factory $AuthSessionCopyWith(
    AuthSession value,
    $Res Function(AuthSession) then,
  ) = _$AuthSessionCopyWithImpl<$Res, AuthSession>;
  @useResult
  $Res call({
    int userId,
    String username,
    String? email,
    String token,
    String expiresAt,
  });
}

/// @nodoc
class _$AuthSessionCopyWithImpl<$Res, $Val extends AuthSession>
    implements $AuthSessionCopyWith<$Res> {
  _$AuthSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? email = freezed,
    Object? token = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as int,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            token: null == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: null == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AuthSessionImplCopyWith<$Res>
    implements $AuthSessionCopyWith<$Res> {
  factory _$$AuthSessionImplCopyWith(
    _$AuthSessionImpl value,
    $Res Function(_$AuthSessionImpl) then,
  ) = __$$AuthSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int userId,
    String username,
    String? email,
    String token,
    String expiresAt,
  });
}

/// @nodoc
class __$$AuthSessionImplCopyWithImpl<$Res>
    extends _$AuthSessionCopyWithImpl<$Res, _$AuthSessionImpl>
    implements _$$AuthSessionImplCopyWith<$Res> {
  __$$AuthSessionImplCopyWithImpl(
    _$AuthSessionImpl _value,
    $Res Function(_$AuthSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? username = null,
    Object? email = freezed,
    Object? token = null,
    Object? expiresAt = null,
  }) {
    return _then(
      _$AuthSessionImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as int,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        token: null == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: null == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AuthSessionImpl implements _AuthSession {
  const _$AuthSessionImpl({
    required this.userId,
    required this.username,
    this.email,
    required this.token,
    required this.expiresAt,
  });

  factory _$AuthSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$AuthSessionImplFromJson(json);

  @override
  final int userId;
  @override
  final String username;
  @override
  final String? email;
  @override
  final String token;
  @override
  final String expiresAt;

  @override
  String toString() {
    return 'AuthSession(userId: $userId, username: $username, email: $email, token: $token, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthSessionImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, username, email, token, expiresAt);

  /// Create a copy of AuthSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthSessionImplCopyWith<_$AuthSessionImpl> get copyWith =>
      __$$AuthSessionImplCopyWithImpl<_$AuthSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AuthSessionImplToJson(this);
  }
}

abstract class _AuthSession implements AuthSession {
  const factory _AuthSession({
    required final int userId,
    required final String username,
    final String? email,
    required final String token,
    required final String expiresAt,
  }) = _$AuthSessionImpl;

  factory _AuthSession.fromJson(Map<String, dynamic> json) =
      _$AuthSessionImpl.fromJson;

  @override
  int get userId;
  @override
  String get username;
  @override
  String? get email;
  @override
  String get token;
  @override
  String get expiresAt;

  /// Create a copy of AuthSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthSessionImplCopyWith<_$AuthSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CurrentUser _$CurrentUserFromJson(Map<String, dynamic> json) {
  return _CurrentUser.fromJson(json);
}

/// @nodoc
mixin _$CurrentUser {
  int get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;

  /// Serializes this CurrentUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CurrentUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CurrentUserCopyWith<CurrentUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CurrentUserCopyWith<$Res> {
  factory $CurrentUserCopyWith(
    CurrentUser value,
    $Res Function(CurrentUser) then,
  ) = _$CurrentUserCopyWithImpl<$Res, CurrentUser>;
  @useResult
  $Res call({int id, String username, String? email});
}

/// @nodoc
class _$CurrentUserCopyWithImpl<$Res, $Val extends CurrentUser>
    implements $CurrentUserCopyWith<$Res> {
  _$CurrentUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CurrentUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? email = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CurrentUserImplCopyWith<$Res>
    implements $CurrentUserCopyWith<$Res> {
  factory _$$CurrentUserImplCopyWith(
    _$CurrentUserImpl value,
    $Res Function(_$CurrentUserImpl) then,
  ) = __$$CurrentUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int id, String username, String? email});
}

/// @nodoc
class __$$CurrentUserImplCopyWithImpl<$Res>
    extends _$CurrentUserCopyWithImpl<$Res, _$CurrentUserImpl>
    implements _$$CurrentUserImplCopyWith<$Res> {
  __$$CurrentUserImplCopyWithImpl(
    _$CurrentUserImpl _value,
    $Res Function(_$CurrentUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CurrentUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? email = freezed,
  }) {
    return _then(
      _$CurrentUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CurrentUserImpl implements _CurrentUser {
  const _$CurrentUserImpl({
    required this.id,
    required this.username,
    this.email,
  });

  factory _$CurrentUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$CurrentUserImplFromJson(json);

  @override
  final int id;
  @override
  final String username;
  @override
  final String? email;

  @override
  String toString() {
    return 'CurrentUser(id: $id, username: $username, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CurrentUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.email, email) || other.email == email));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, username, email);

  /// Create a copy of CurrentUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CurrentUserImplCopyWith<_$CurrentUserImpl> get copyWith =>
      __$$CurrentUserImplCopyWithImpl<_$CurrentUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CurrentUserImplToJson(this);
  }
}

abstract class _CurrentUser implements CurrentUser {
  const factory _CurrentUser({
    required final int id,
    required final String username,
    final String? email,
  }) = _$CurrentUserImpl;

  factory _CurrentUser.fromJson(Map<String, dynamic> json) =
      _$CurrentUserImpl.fromJson;

  @override
  int get id;
  @override
  String get username;
  @override
  String? get email;

  /// Create a copy of CurrentUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CurrentUserImplCopyWith<_$CurrentUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DeviceRequest _$DeviceRequestFromJson(Map<String, dynamic> json) {
  return _DeviceRequest.fromJson(json);
}

/// @nodoc
mixin _$DeviceRequest {
  String get deviceId => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get platform => throw _privateConstructorUsedError;

  /// Serializes this DeviceRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceRequestCopyWith<DeviceRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceRequestCopyWith<$Res> {
  factory $DeviceRequestCopyWith(
    DeviceRequest value,
    $Res Function(DeviceRequest) then,
  ) = _$DeviceRequestCopyWithImpl<$Res, DeviceRequest>;
  @useResult
  $Res call({String deviceId, String? name, String? platform});
}

/// @nodoc
class _$DeviceRequestCopyWithImpl<$Res, $Val extends DeviceRequest>
    implements $DeviceRequestCopyWith<$Res> {
  _$DeviceRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? name = freezed,
    Object? platform = freezed,
  }) {
    return _then(
      _value.copyWith(
            deviceId: null == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
            platform: freezed == platform
                ? _value.platform
                : platform // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceRequestImplCopyWith<$Res>
    implements $DeviceRequestCopyWith<$Res> {
  factory _$$DeviceRequestImplCopyWith(
    _$DeviceRequestImpl value,
    $Res Function(_$DeviceRequestImpl) then,
  ) = __$$DeviceRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String deviceId, String? name, String? platform});
}

/// @nodoc
class __$$DeviceRequestImplCopyWithImpl<$Res>
    extends _$DeviceRequestCopyWithImpl<$Res, _$DeviceRequestImpl>
    implements _$$DeviceRequestImplCopyWith<$Res> {
  __$$DeviceRequestImplCopyWithImpl(
    _$DeviceRequestImpl _value,
    $Res Function(_$DeviceRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeviceRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deviceId = null,
    Object? name = freezed,
    Object? platform = freezed,
  }) {
    return _then(
      _$DeviceRequestImpl(
        deviceId: null == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        platform: freezed == platform
            ? _value.platform
            : platform // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceRequestImpl implements _DeviceRequest {
  const _$DeviceRequestImpl({required this.deviceId, this.name, this.platform});

  factory _$DeviceRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceRequestImplFromJson(json);

  @override
  final String deviceId;
  @override
  final String? name;
  @override
  final String? platform;

  @override
  String toString() {
    return 'DeviceRequest(deviceId: $deviceId, name: $name, platform: $platform)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceRequestImpl &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.platform, platform) ||
                other.platform == platform));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, deviceId, name, platform);

  /// Create a copy of DeviceRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceRequestImplCopyWith<_$DeviceRequestImpl> get copyWith =>
      __$$DeviceRequestImplCopyWithImpl<_$DeviceRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceRequestImplToJson(this);
  }
}

abstract class _DeviceRequest implements DeviceRequest {
  const factory _DeviceRequest({
    required final String deviceId,
    final String? name,
    final String? platform,
  }) = _$DeviceRequestImpl;

  factory _DeviceRequest.fromJson(Map<String, dynamic> json) =
      _$DeviceRequestImpl.fromJson;

  @override
  String get deviceId;
  @override
  String? get name;
  @override
  String? get platform;

  /// Create a copy of DeviceRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceRequestImplCopyWith<_$DeviceRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DeviceDto _$DeviceDtoFromJson(Map<String, dynamic> json) {
  return _DeviceDto.fromJson(json);
}

/// @nodoc
mixin _$DeviceDto {
  int? get id => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get platform => throw _privateConstructorUsedError;
  String? get lastSyncedAt => throw _privateConstructorUsedError;
  String? get lastSeenAt => throw _privateConstructorUsedError;

  /// Serializes this DeviceDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceDtoCopyWith<DeviceDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceDtoCopyWith<$Res> {
  factory $DeviceDtoCopyWith(DeviceDto value, $Res Function(DeviceDto) then) =
      _$DeviceDtoCopyWithImpl<$Res, DeviceDto>;
  @useResult
  $Res call({
    int? id,
    String deviceId,
    String? name,
    String? platform,
    String? lastSyncedAt,
    String? lastSeenAt,
  });
}

/// @nodoc
class _$DeviceDtoCopyWithImpl<$Res, $Val extends DeviceDto>
    implements $DeviceDtoCopyWith<$Res> {
  _$DeviceDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? deviceId = null,
    Object? name = freezed,
    Object? platform = freezed,
    Object? lastSyncedAt = freezed,
    Object? lastSeenAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int?,
            deviceId: null == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
            platform: freezed == platform
                ? _value.platform
                : platform // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastSyncedAt: freezed == lastSyncedAt
                ? _value.lastSyncedAt
                : lastSyncedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastSeenAt: freezed == lastSeenAt
                ? _value.lastSeenAt
                : lastSeenAt // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceDtoImplCopyWith<$Res>
    implements $DeviceDtoCopyWith<$Res> {
  factory _$$DeviceDtoImplCopyWith(
    _$DeviceDtoImpl value,
    $Res Function(_$DeviceDtoImpl) then,
  ) = __$$DeviceDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? id,
    String deviceId,
    String? name,
    String? platform,
    String? lastSyncedAt,
    String? lastSeenAt,
  });
}

/// @nodoc
class __$$DeviceDtoImplCopyWithImpl<$Res>
    extends _$DeviceDtoCopyWithImpl<$Res, _$DeviceDtoImpl>
    implements _$$DeviceDtoImplCopyWith<$Res> {
  __$$DeviceDtoImplCopyWithImpl(
    _$DeviceDtoImpl _value,
    $Res Function(_$DeviceDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeviceDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? deviceId = null,
    Object? name = freezed,
    Object? platform = freezed,
    Object? lastSyncedAt = freezed,
    Object? lastSeenAt = freezed,
  }) {
    return _then(
      _$DeviceDtoImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int?,
        deviceId: null == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        platform: freezed == platform
            ? _value.platform
            : platform // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastSyncedAt: freezed == lastSyncedAt
            ? _value.lastSyncedAt
            : lastSyncedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastSeenAt: freezed == lastSeenAt
            ? _value.lastSeenAt
            : lastSeenAt // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceDtoImpl implements _DeviceDto {
  const _$DeviceDtoImpl({
    this.id,
    required this.deviceId,
    this.name,
    this.platform,
    this.lastSyncedAt,
    this.lastSeenAt,
  });

  factory _$DeviceDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceDtoImplFromJson(json);

  @override
  final int? id;
  @override
  final String deviceId;
  @override
  final String? name;
  @override
  final String? platform;
  @override
  final String? lastSyncedAt;
  @override
  final String? lastSeenAt;

  @override
  String toString() {
    return 'DeviceDto(id: $id, deviceId: $deviceId, name: $name, platform: $platform, lastSyncedAt: $lastSyncedAt, lastSeenAt: $lastSeenAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceDtoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.lastSyncedAt, lastSyncedAt) ||
                other.lastSyncedAt == lastSyncedAt) &&
            (identical(other.lastSeenAt, lastSeenAt) ||
                other.lastSeenAt == lastSeenAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    deviceId,
    name,
    platform,
    lastSyncedAt,
    lastSeenAt,
  );

  /// Create a copy of DeviceDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceDtoImplCopyWith<_$DeviceDtoImpl> get copyWith =>
      __$$DeviceDtoImplCopyWithImpl<_$DeviceDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceDtoImplToJson(this);
  }
}

abstract class _DeviceDto implements DeviceDto {
  const factory _DeviceDto({
    final int? id,
    required final String deviceId,
    final String? name,
    final String? platform,
    final String? lastSyncedAt,
    final String? lastSeenAt,
  }) = _$DeviceDtoImpl;

  factory _DeviceDto.fromJson(Map<String, dynamic> json) =
      _$DeviceDtoImpl.fromJson;

  @override
  int? get id;
  @override
  String get deviceId;
  @override
  String? get name;
  @override
  String? get platform;
  @override
  String? get lastSyncedAt;
  @override
  String? get lastSeenAt;

  /// Create a copy of DeviceDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceDtoImplCopyWith<_$DeviceDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
