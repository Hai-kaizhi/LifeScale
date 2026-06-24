// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vault_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VaultChangeSummary _$VaultChangeSummaryFromJson(Map<String, dynamic> json) {
  return _VaultChangeSummary.fromJson(json);
}

/// @nodoc
mixin _$VaultChangeSummary {
  String get vaultPath => throw _privateConstructorUsedError;
  String get contentHash => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  String get serverMtime => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;

  /// Serializes this VaultChangeSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VaultChangeSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VaultChangeSummaryCopyWith<VaultChangeSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VaultChangeSummaryCopyWith<$Res> {
  factory $VaultChangeSummaryCopyWith(
    VaultChangeSummary value,
    $Res Function(VaultChangeSummary) then,
  ) = _$VaultChangeSummaryCopyWithImpl<$Res, VaultChangeSummary>;
  @useResult
  $Res call({
    String vaultPath,
    String contentHash,
    int version,
    String serverMtime,
    String status,
    int size,
  });
}

/// @nodoc
class _$VaultChangeSummaryCopyWithImpl<$Res, $Val extends VaultChangeSummary>
    implements $VaultChangeSummaryCopyWith<$Res> {
  _$VaultChangeSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VaultChangeSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vaultPath = null,
    Object? contentHash = null,
    Object? version = null,
    Object? serverMtime = null,
    Object? status = null,
    Object? size = null,
  }) {
    return _then(
      _value.copyWith(
            vaultPath: null == vaultPath
                ? _value.vaultPath
                : vaultPath // ignore: cast_nullable_to_non_nullable
                      as String,
            contentHash: null == contentHash
                ? _value.contentHash
                : contentHash // ignore: cast_nullable_to_non_nullable
                      as String,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            serverMtime: null == serverMtime
                ? _value.serverMtime
                : serverMtime // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VaultChangeSummaryImplCopyWith<$Res>
    implements $VaultChangeSummaryCopyWith<$Res> {
  factory _$$VaultChangeSummaryImplCopyWith(
    _$VaultChangeSummaryImpl value,
    $Res Function(_$VaultChangeSummaryImpl) then,
  ) = __$$VaultChangeSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String vaultPath,
    String contentHash,
    int version,
    String serverMtime,
    String status,
    int size,
  });
}

/// @nodoc
class __$$VaultChangeSummaryImplCopyWithImpl<$Res>
    extends _$VaultChangeSummaryCopyWithImpl<$Res, _$VaultChangeSummaryImpl>
    implements _$$VaultChangeSummaryImplCopyWith<$Res> {
  __$$VaultChangeSummaryImplCopyWithImpl(
    _$VaultChangeSummaryImpl _value,
    $Res Function(_$VaultChangeSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VaultChangeSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vaultPath = null,
    Object? contentHash = null,
    Object? version = null,
    Object? serverMtime = null,
    Object? status = null,
    Object? size = null,
  }) {
    return _then(
      _$VaultChangeSummaryImpl(
        vaultPath: null == vaultPath
            ? _value.vaultPath
            : vaultPath // ignore: cast_nullable_to_non_nullable
                  as String,
        contentHash: null == contentHash
            ? _value.contentHash
            : contentHash // ignore: cast_nullable_to_non_nullable
                  as String,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        serverMtime: null == serverMtime
            ? _value.serverMtime
            : serverMtime // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VaultChangeSummaryImpl implements _VaultChangeSummary {
  const _$VaultChangeSummaryImpl({
    required this.vaultPath,
    required this.contentHash,
    required this.version,
    required this.serverMtime,
    required this.status,
    required this.size,
  });

  factory _$VaultChangeSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$VaultChangeSummaryImplFromJson(json);

  @override
  final String vaultPath;
  @override
  final String contentHash;
  @override
  final int version;
  @override
  final String serverMtime;
  @override
  final String status;
  @override
  final int size;

  @override
  String toString() {
    return 'VaultChangeSummary(vaultPath: $vaultPath, contentHash: $contentHash, version: $version, serverMtime: $serverMtime, status: $status, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VaultChangeSummaryImpl &&
            (identical(other.vaultPath, vaultPath) ||
                other.vaultPath == vaultPath) &&
            (identical(other.contentHash, contentHash) ||
                other.contentHash == contentHash) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.serverMtime, serverMtime) ||
                other.serverMtime == serverMtime) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.size, size) || other.size == size));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    vaultPath,
    contentHash,
    version,
    serverMtime,
    status,
    size,
  );

  /// Create a copy of VaultChangeSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VaultChangeSummaryImplCopyWith<_$VaultChangeSummaryImpl> get copyWith =>
      __$$VaultChangeSummaryImplCopyWithImpl<_$VaultChangeSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VaultChangeSummaryImplToJson(this);
  }
}

abstract class _VaultChangeSummary implements VaultChangeSummary {
  const factory _VaultChangeSummary({
    required final String vaultPath,
    required final String contentHash,
    required final int version,
    required final String serverMtime,
    required final String status,
    required final int size,
  }) = _$VaultChangeSummaryImpl;

  factory _VaultChangeSummary.fromJson(Map<String, dynamic> json) =
      _$VaultChangeSummaryImpl.fromJson;

  @override
  String get vaultPath;
  @override
  String get contentHash;
  @override
  int get version;
  @override
  String get serverMtime;
  @override
  String get status;
  @override
  int get size;

  /// Create a copy of VaultChangeSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VaultChangeSummaryImplCopyWith<_$VaultChangeSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VaultChangesData _$VaultChangesDataFromJson(Map<String, dynamic> json) {
  return _VaultChangesData.fromJson(json);
}

/// @nodoc
mixin _$VaultChangesData {
  List<VaultChangeSummary> get changes => throw _privateConstructorUsedError;
  String get serverTime => throw _privateConstructorUsedError;
  String? get nextCursor => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;

  /// Serializes this VaultChangesData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VaultChangesData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VaultChangesDataCopyWith<VaultChangesData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VaultChangesDataCopyWith<$Res> {
  factory $VaultChangesDataCopyWith(
    VaultChangesData value,
    $Res Function(VaultChangesData) then,
  ) = _$VaultChangesDataCopyWithImpl<$Res, VaultChangesData>;
  @useResult
  $Res call({
    List<VaultChangeSummary> changes,
    String serverTime,
    String? nextCursor,
    bool hasMore,
  });
}

/// @nodoc
class _$VaultChangesDataCopyWithImpl<$Res, $Val extends VaultChangesData>
    implements $VaultChangesDataCopyWith<$Res> {
  _$VaultChangesDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VaultChangesData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? changes = null,
    Object? serverTime = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _value.copyWith(
            changes: null == changes
                ? _value.changes
                : changes // ignore: cast_nullable_to_non_nullable
                      as List<VaultChangeSummary>,
            serverTime: null == serverTime
                ? _value.serverTime
                : serverTime // ignore: cast_nullable_to_non_nullable
                      as String,
            nextCursor: freezed == nextCursor
                ? _value.nextCursor
                : nextCursor // ignore: cast_nullable_to_non_nullable
                      as String?,
            hasMore: null == hasMore
                ? _value.hasMore
                : hasMore // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VaultChangesDataImplCopyWith<$Res>
    implements $VaultChangesDataCopyWith<$Res> {
  factory _$$VaultChangesDataImplCopyWith(
    _$VaultChangesDataImpl value,
    $Res Function(_$VaultChangesDataImpl) then,
  ) = __$$VaultChangesDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<VaultChangeSummary> changes,
    String serverTime,
    String? nextCursor,
    bool hasMore,
  });
}

/// @nodoc
class __$$VaultChangesDataImplCopyWithImpl<$Res>
    extends _$VaultChangesDataCopyWithImpl<$Res, _$VaultChangesDataImpl>
    implements _$$VaultChangesDataImplCopyWith<$Res> {
  __$$VaultChangesDataImplCopyWithImpl(
    _$VaultChangesDataImpl _value,
    $Res Function(_$VaultChangesDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VaultChangesData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? changes = null,
    Object? serverTime = null,
    Object? nextCursor = freezed,
    Object? hasMore = null,
  }) {
    return _then(
      _$VaultChangesDataImpl(
        changes: null == changes
            ? _value._changes
            : changes // ignore: cast_nullable_to_non_nullable
                  as List<VaultChangeSummary>,
        serverTime: null == serverTime
            ? _value.serverTime
            : serverTime // ignore: cast_nullable_to_non_nullable
                  as String,
        nextCursor: freezed == nextCursor
            ? _value.nextCursor
            : nextCursor // ignore: cast_nullable_to_non_nullable
                  as String?,
        hasMore: null == hasMore
            ? _value.hasMore
            : hasMore // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VaultChangesDataImpl implements _VaultChangesData {
  const _$VaultChangesDataImpl({
    final List<VaultChangeSummary> changes = const <VaultChangeSummary>[],
    required this.serverTime,
    this.nextCursor,
    this.hasMore = false,
  }) : _changes = changes;

  factory _$VaultChangesDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$VaultChangesDataImplFromJson(json);

  final List<VaultChangeSummary> _changes;
  @override
  @JsonKey()
  List<VaultChangeSummary> get changes {
    if (_changes is EqualUnmodifiableListView) return _changes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_changes);
  }

  @override
  final String serverTime;
  @override
  final String? nextCursor;
  @override
  @JsonKey()
  final bool hasMore;

  @override
  String toString() {
    return 'VaultChangesData(changes: $changes, serverTime: $serverTime, nextCursor: $nextCursor, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VaultChangesDataImpl &&
            const DeepCollectionEquality().equals(other._changes, _changes) &&
            (identical(other.serverTime, serverTime) ||
                other.serverTime == serverTime) &&
            (identical(other.nextCursor, nextCursor) ||
                other.nextCursor == nextCursor) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_changes),
    serverTime,
    nextCursor,
    hasMore,
  );

  /// Create a copy of VaultChangesData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VaultChangesDataImplCopyWith<_$VaultChangesDataImpl> get copyWith =>
      __$$VaultChangesDataImplCopyWithImpl<_$VaultChangesDataImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VaultChangesDataImplToJson(this);
  }
}

abstract class _VaultChangesData implements VaultChangesData {
  const factory _VaultChangesData({
    final List<VaultChangeSummary> changes,
    required final String serverTime,
    final String? nextCursor,
    final bool hasMore,
  }) = _$VaultChangesDataImpl;

  factory _VaultChangesData.fromJson(Map<String, dynamic> json) =
      _$VaultChangesDataImpl.fromJson;

  @override
  List<VaultChangeSummary> get changes;
  @override
  String get serverTime;
  @override
  String? get nextCursor;
  @override
  bool get hasMore;

  /// Create a copy of VaultChangesData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VaultChangesDataImplCopyWith<_$VaultChangesDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VaultFileData _$VaultFileDataFromJson(Map<String, dynamic> json) {
  return _VaultFileData.fromJson(json);
}

/// @nodoc
mixin _$VaultFileData {
  String get vaultPath => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String get contentHash => throw _privateConstructorUsedError;
  int get version => throw _privateConstructorUsedError;
  String get serverMtime => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;

  /// Serializes this VaultFileData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VaultFileData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VaultFileDataCopyWith<VaultFileData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VaultFileDataCopyWith<$Res> {
  factory $VaultFileDataCopyWith(
    VaultFileData value,
    $Res Function(VaultFileData) then,
  ) = _$VaultFileDataCopyWithImpl<$Res, VaultFileData>;
  @useResult
  $Res call({
    String vaultPath,
    String content,
    String contentHash,
    int version,
    String serverMtime,
    int size,
  });
}

/// @nodoc
class _$VaultFileDataCopyWithImpl<$Res, $Val extends VaultFileData>
    implements $VaultFileDataCopyWith<$Res> {
  _$VaultFileDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VaultFileData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vaultPath = null,
    Object? content = null,
    Object? contentHash = null,
    Object? version = null,
    Object? serverMtime = null,
    Object? size = null,
  }) {
    return _then(
      _value.copyWith(
            vaultPath: null == vaultPath
                ? _value.vaultPath
                : vaultPath // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            contentHash: null == contentHash
                ? _value.contentHash
                : contentHash // ignore: cast_nullable_to_non_nullable
                      as String,
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as int,
            serverMtime: null == serverMtime
                ? _value.serverMtime
                : serverMtime // ignore: cast_nullable_to_non_nullable
                      as String,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VaultFileDataImplCopyWith<$Res>
    implements $VaultFileDataCopyWith<$Res> {
  factory _$$VaultFileDataImplCopyWith(
    _$VaultFileDataImpl value,
    $Res Function(_$VaultFileDataImpl) then,
  ) = __$$VaultFileDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String vaultPath,
    String content,
    String contentHash,
    int version,
    String serverMtime,
    int size,
  });
}

/// @nodoc
class __$$VaultFileDataImplCopyWithImpl<$Res>
    extends _$VaultFileDataCopyWithImpl<$Res, _$VaultFileDataImpl>
    implements _$$VaultFileDataImplCopyWith<$Res> {
  __$$VaultFileDataImplCopyWithImpl(
    _$VaultFileDataImpl _value,
    $Res Function(_$VaultFileDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VaultFileData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vaultPath = null,
    Object? content = null,
    Object? contentHash = null,
    Object? version = null,
    Object? serverMtime = null,
    Object? size = null,
  }) {
    return _then(
      _$VaultFileDataImpl(
        vaultPath: null == vaultPath
            ? _value.vaultPath
            : vaultPath // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        contentHash: null == contentHash
            ? _value.contentHash
            : contentHash // ignore: cast_nullable_to_non_nullable
                  as String,
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as int,
        serverMtime: null == serverMtime
            ? _value.serverMtime
            : serverMtime // ignore: cast_nullable_to_non_nullable
                  as String,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VaultFileDataImpl implements _VaultFileData {
  const _$VaultFileDataImpl({
    required this.vaultPath,
    required this.content,
    required this.contentHash,
    required this.version,
    required this.serverMtime,
    required this.size,
  });

  factory _$VaultFileDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$VaultFileDataImplFromJson(json);

  @override
  final String vaultPath;
  @override
  final String content;
  @override
  final String contentHash;
  @override
  final int version;
  @override
  final String serverMtime;
  @override
  final int size;

  @override
  String toString() {
    return 'VaultFileData(vaultPath: $vaultPath, content: $content, contentHash: $contentHash, version: $version, serverMtime: $serverMtime, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VaultFileDataImpl &&
            (identical(other.vaultPath, vaultPath) ||
                other.vaultPath == vaultPath) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.contentHash, contentHash) ||
                other.contentHash == contentHash) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.serverMtime, serverMtime) ||
                other.serverMtime == serverMtime) &&
            (identical(other.size, size) || other.size == size));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    vaultPath,
    content,
    contentHash,
    version,
    serverMtime,
    size,
  );

  /// Create a copy of VaultFileData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VaultFileDataImplCopyWith<_$VaultFileDataImpl> get copyWith =>
      __$$VaultFileDataImplCopyWithImpl<_$VaultFileDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VaultFileDataImplToJson(this);
  }
}

abstract class _VaultFileData implements VaultFileData {
  const factory _VaultFileData({
    required final String vaultPath,
    required final String content,
    required final String contentHash,
    required final int version,
    required final String serverMtime,
    required final int size,
  }) = _$VaultFileDataImpl;

  factory _VaultFileData.fromJson(Map<String, dynamic> json) =
      _$VaultFileDataImpl.fromJson;

  @override
  String get vaultPath;
  @override
  String get content;
  @override
  String get contentHash;
  @override
  int get version;
  @override
  String get serverMtime;
  @override
  int get size;

  /// Create a copy of VaultFileData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VaultFileDataImplCopyWith<_$VaultFileDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VaultPushPayload _$VaultPushPayloadFromJson(Map<String, dynamic> json) {
  return _VaultPushPayload.fromJson(json);
}

/// @nodoc
mixin _$VaultPushPayload {
  String get vaultPath => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  String? get ifMatchHash => throw _privateConstructorUsedError;
  String? get deviceId => throw _privateConstructorUsedError;

  /// Serializes this VaultPushPayload to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VaultPushPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VaultPushPayloadCopyWith<VaultPushPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VaultPushPayloadCopyWith<$Res> {
  factory $VaultPushPayloadCopyWith(
    VaultPushPayload value,
    $Res Function(VaultPushPayload) then,
  ) = _$VaultPushPayloadCopyWithImpl<$Res, VaultPushPayload>;
  @useResult
  $Res call({
    String vaultPath,
    String? content,
    String? ifMatchHash,
    String? deviceId,
  });
}

/// @nodoc
class _$VaultPushPayloadCopyWithImpl<$Res, $Val extends VaultPushPayload>
    implements $VaultPushPayloadCopyWith<$Res> {
  _$VaultPushPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VaultPushPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vaultPath = null,
    Object? content = freezed,
    Object? ifMatchHash = freezed,
    Object? deviceId = freezed,
  }) {
    return _then(
      _value.copyWith(
            vaultPath: null == vaultPath
                ? _value.vaultPath
                : vaultPath // ignore: cast_nullable_to_non_nullable
                      as String,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String?,
            ifMatchHash: freezed == ifMatchHash
                ? _value.ifMatchHash
                : ifMatchHash // ignore: cast_nullable_to_non_nullable
                      as String?,
            deviceId: freezed == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VaultPushPayloadImplCopyWith<$Res>
    implements $VaultPushPayloadCopyWith<$Res> {
  factory _$$VaultPushPayloadImplCopyWith(
    _$VaultPushPayloadImpl value,
    $Res Function(_$VaultPushPayloadImpl) then,
  ) = __$$VaultPushPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String vaultPath,
    String? content,
    String? ifMatchHash,
    String? deviceId,
  });
}

/// @nodoc
class __$$VaultPushPayloadImplCopyWithImpl<$Res>
    extends _$VaultPushPayloadCopyWithImpl<$Res, _$VaultPushPayloadImpl>
    implements _$$VaultPushPayloadImplCopyWith<$Res> {
  __$$VaultPushPayloadImplCopyWithImpl(
    _$VaultPushPayloadImpl _value,
    $Res Function(_$VaultPushPayloadImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VaultPushPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vaultPath = null,
    Object? content = freezed,
    Object? ifMatchHash = freezed,
    Object? deviceId = freezed,
  }) {
    return _then(
      _$VaultPushPayloadImpl(
        vaultPath: null == vaultPath
            ? _value.vaultPath
            : vaultPath // ignore: cast_nullable_to_non_nullable
                  as String,
        content: freezed == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        ifMatchHash: freezed == ifMatchHash
            ? _value.ifMatchHash
            : ifMatchHash // ignore: cast_nullable_to_non_nullable
                  as String?,
        deviceId: freezed == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VaultPushPayloadImpl implements _VaultPushPayload {
  const _$VaultPushPayloadImpl({
    required this.vaultPath,
    this.content,
    this.ifMatchHash,
    this.deviceId,
  });

  factory _$VaultPushPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$VaultPushPayloadImplFromJson(json);

  @override
  final String vaultPath;
  @override
  final String? content;
  @override
  final String? ifMatchHash;
  @override
  final String? deviceId;

  @override
  String toString() {
    return 'VaultPushPayload(vaultPath: $vaultPath, content: $content, ifMatchHash: $ifMatchHash, deviceId: $deviceId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VaultPushPayloadImpl &&
            (identical(other.vaultPath, vaultPath) ||
                other.vaultPath == vaultPath) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.ifMatchHash, ifMatchHash) ||
                other.ifMatchHash == ifMatchHash) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, vaultPath, content, ifMatchHash, deviceId);

  /// Create a copy of VaultPushPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VaultPushPayloadImplCopyWith<_$VaultPushPayloadImpl> get copyWith =>
      __$$VaultPushPayloadImplCopyWithImpl<_$VaultPushPayloadImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VaultPushPayloadImplToJson(this);
  }
}

abstract class _VaultPushPayload implements VaultPushPayload {
  const factory _VaultPushPayload({
    required final String vaultPath,
    final String? content,
    final String? ifMatchHash,
    final String? deviceId,
  }) = _$VaultPushPayloadImpl;

  factory _VaultPushPayload.fromJson(Map<String, dynamic> json) =
      _$VaultPushPayloadImpl.fromJson;

  @override
  String get vaultPath;
  @override
  String? get content;
  @override
  String? get ifMatchHash;
  @override
  String? get deviceId;

  /// Create a copy of VaultPushPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VaultPushPayloadImplCopyWith<_$VaultPushPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConflictView _$ConflictViewFromJson(Map<String, dynamic> json) {
  return _ConflictView.fromJson(json);
}

/// @nodoc
mixin _$ConflictView {
  String? get baseHash => throw _privateConstructorUsedError;
  String? get theirsHash => throw _privateConstructorUsedError;
  String? get theirsContent => throw _privateConstructorUsedError;
  String? get conflictCopyPath => throw _privateConstructorUsedError;
  int? get conflictId => throw _privateConstructorUsedError;

  /// Serializes this ConflictView to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConflictView
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConflictViewCopyWith<ConflictView> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConflictViewCopyWith<$Res> {
  factory $ConflictViewCopyWith(
    ConflictView value,
    $Res Function(ConflictView) then,
  ) = _$ConflictViewCopyWithImpl<$Res, ConflictView>;
  @useResult
  $Res call({
    String? baseHash,
    String? theirsHash,
    String? theirsContent,
    String? conflictCopyPath,
    int? conflictId,
  });
}

/// @nodoc
class _$ConflictViewCopyWithImpl<$Res, $Val extends ConflictView>
    implements $ConflictViewCopyWith<$Res> {
  _$ConflictViewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConflictView
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseHash = freezed,
    Object? theirsHash = freezed,
    Object? theirsContent = freezed,
    Object? conflictCopyPath = freezed,
    Object? conflictId = freezed,
  }) {
    return _then(
      _value.copyWith(
            baseHash: freezed == baseHash
                ? _value.baseHash
                : baseHash // ignore: cast_nullable_to_non_nullable
                      as String?,
            theirsHash: freezed == theirsHash
                ? _value.theirsHash
                : theirsHash // ignore: cast_nullable_to_non_nullable
                      as String?,
            theirsContent: freezed == theirsContent
                ? _value.theirsContent
                : theirsContent // ignore: cast_nullable_to_non_nullable
                      as String?,
            conflictCopyPath: freezed == conflictCopyPath
                ? _value.conflictCopyPath
                : conflictCopyPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            conflictId: freezed == conflictId
                ? _value.conflictId
                : conflictId // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConflictViewImplCopyWith<$Res>
    implements $ConflictViewCopyWith<$Res> {
  factory _$$ConflictViewImplCopyWith(
    _$ConflictViewImpl value,
    $Res Function(_$ConflictViewImpl) then,
  ) = __$$ConflictViewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? baseHash,
    String? theirsHash,
    String? theirsContent,
    String? conflictCopyPath,
    int? conflictId,
  });
}

/// @nodoc
class __$$ConflictViewImplCopyWithImpl<$Res>
    extends _$ConflictViewCopyWithImpl<$Res, _$ConflictViewImpl>
    implements _$$ConflictViewImplCopyWith<$Res> {
  __$$ConflictViewImplCopyWithImpl(
    _$ConflictViewImpl _value,
    $Res Function(_$ConflictViewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConflictView
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? baseHash = freezed,
    Object? theirsHash = freezed,
    Object? theirsContent = freezed,
    Object? conflictCopyPath = freezed,
    Object? conflictId = freezed,
  }) {
    return _then(
      _$ConflictViewImpl(
        baseHash: freezed == baseHash
            ? _value.baseHash
            : baseHash // ignore: cast_nullable_to_non_nullable
                  as String?,
        theirsHash: freezed == theirsHash
            ? _value.theirsHash
            : theirsHash // ignore: cast_nullable_to_non_nullable
                  as String?,
        theirsContent: freezed == theirsContent
            ? _value.theirsContent
            : theirsContent // ignore: cast_nullable_to_non_nullable
                  as String?,
        conflictCopyPath: freezed == conflictCopyPath
            ? _value.conflictCopyPath
            : conflictCopyPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        conflictId: freezed == conflictId
            ? _value.conflictId
            : conflictId // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConflictViewImpl implements _ConflictView {
  const _$ConflictViewImpl({
    this.baseHash,
    this.theirsHash,
    this.theirsContent,
    this.conflictCopyPath,
    this.conflictId,
  });

  factory _$ConflictViewImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConflictViewImplFromJson(json);

  @override
  final String? baseHash;
  @override
  final String? theirsHash;
  @override
  final String? theirsContent;
  @override
  final String? conflictCopyPath;
  @override
  final int? conflictId;

  @override
  String toString() {
    return 'ConflictView(baseHash: $baseHash, theirsHash: $theirsHash, theirsContent: $theirsContent, conflictCopyPath: $conflictCopyPath, conflictId: $conflictId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConflictViewImpl &&
            (identical(other.baseHash, baseHash) ||
                other.baseHash == baseHash) &&
            (identical(other.theirsHash, theirsHash) ||
                other.theirsHash == theirsHash) &&
            (identical(other.theirsContent, theirsContent) ||
                other.theirsContent == theirsContent) &&
            (identical(other.conflictCopyPath, conflictCopyPath) ||
                other.conflictCopyPath == conflictCopyPath) &&
            (identical(other.conflictId, conflictId) ||
                other.conflictId == conflictId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    baseHash,
    theirsHash,
    theirsContent,
    conflictCopyPath,
    conflictId,
  );

  /// Create a copy of ConflictView
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConflictViewImplCopyWith<_$ConflictViewImpl> get copyWith =>
      __$$ConflictViewImplCopyWithImpl<_$ConflictViewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConflictViewImplToJson(this);
  }
}

abstract class _ConflictView implements ConflictView {
  const factory _ConflictView({
    final String? baseHash,
    final String? theirsHash,
    final String? theirsContent,
    final String? conflictCopyPath,
    final int? conflictId,
  }) = _$ConflictViewImpl;

  factory _ConflictView.fromJson(Map<String, dynamic> json) =
      _$ConflictViewImpl.fromJson;

  @override
  String? get baseHash;
  @override
  String? get theirsHash;
  @override
  String? get theirsContent;
  @override
  String? get conflictCopyPath;
  @override
  int? get conflictId;

  /// Create a copy of ConflictView
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConflictViewImplCopyWith<_$ConflictViewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConflictItem _$ConflictItemFromJson(Map<String, dynamic> json) {
  return _ConflictItem.fromJson(json);
}

/// @nodoc
mixin _$ConflictItem {
  int get conflictId => throw _privateConstructorUsedError;
  String get vaultPath => throw _privateConstructorUsedError;
  String? get mineHash => throw _privateConstructorUsedError;
  String? get theirsHash => throw _privateConstructorUsedError;
  String get theirsContent => throw _privateConstructorUsedError;
  String? get conflictCopyPath => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  String? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this ConflictItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConflictItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConflictItemCopyWith<ConflictItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConflictItemCopyWith<$Res> {
  factory $ConflictItemCopyWith(
    ConflictItem value,
    $Res Function(ConflictItem) then,
  ) = _$ConflictItemCopyWithImpl<$Res, ConflictItem>;
  @useResult
  $Res call({
    int conflictId,
    String vaultPath,
    String? mineHash,
    String? theirsHash,
    String theirsContent,
    String? conflictCopyPath,
    String? status,
    String? createdAt,
  });
}

/// @nodoc
class _$ConflictItemCopyWithImpl<$Res, $Val extends ConflictItem>
    implements $ConflictItemCopyWith<$Res> {
  _$ConflictItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConflictItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? conflictId = null,
    Object? vaultPath = null,
    Object? mineHash = freezed,
    Object? theirsHash = freezed,
    Object? theirsContent = null,
    Object? conflictCopyPath = freezed,
    Object? status = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            conflictId: null == conflictId
                ? _value.conflictId
                : conflictId // ignore: cast_nullable_to_non_nullable
                      as int,
            vaultPath: null == vaultPath
                ? _value.vaultPath
                : vaultPath // ignore: cast_nullable_to_non_nullable
                      as String,
            mineHash: freezed == mineHash
                ? _value.mineHash
                : mineHash // ignore: cast_nullable_to_non_nullable
                      as String?,
            theirsHash: freezed == theirsHash
                ? _value.theirsHash
                : theirsHash // ignore: cast_nullable_to_non_nullable
                      as String?,
            theirsContent: null == theirsContent
                ? _value.theirsContent
                : theirsContent // ignore: cast_nullable_to_non_nullable
                      as String,
            conflictCopyPath: freezed == conflictCopyPath
                ? _value.conflictCopyPath
                : conflictCopyPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConflictItemImplCopyWith<$Res>
    implements $ConflictItemCopyWith<$Res> {
  factory _$$ConflictItemImplCopyWith(
    _$ConflictItemImpl value,
    $Res Function(_$ConflictItemImpl) then,
  ) = __$$ConflictItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int conflictId,
    String vaultPath,
    String? mineHash,
    String? theirsHash,
    String theirsContent,
    String? conflictCopyPath,
    String? status,
    String? createdAt,
  });
}

/// @nodoc
class __$$ConflictItemImplCopyWithImpl<$Res>
    extends _$ConflictItemCopyWithImpl<$Res, _$ConflictItemImpl>
    implements _$$ConflictItemImplCopyWith<$Res> {
  __$$ConflictItemImplCopyWithImpl(
    _$ConflictItemImpl _value,
    $Res Function(_$ConflictItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConflictItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? conflictId = null,
    Object? vaultPath = null,
    Object? mineHash = freezed,
    Object? theirsHash = freezed,
    Object? theirsContent = null,
    Object? conflictCopyPath = freezed,
    Object? status = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$ConflictItemImpl(
        conflictId: null == conflictId
            ? _value.conflictId
            : conflictId // ignore: cast_nullable_to_non_nullable
                  as int,
        vaultPath: null == vaultPath
            ? _value.vaultPath
            : vaultPath // ignore: cast_nullable_to_non_nullable
                  as String,
        mineHash: freezed == mineHash
            ? _value.mineHash
            : mineHash // ignore: cast_nullable_to_non_nullable
                  as String?,
        theirsHash: freezed == theirsHash
            ? _value.theirsHash
            : theirsHash // ignore: cast_nullable_to_non_nullable
                  as String?,
        theirsContent: null == theirsContent
            ? _value.theirsContent
            : theirsContent // ignore: cast_nullable_to_non_nullable
                  as String,
        conflictCopyPath: freezed == conflictCopyPath
            ? _value.conflictCopyPath
            : conflictCopyPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConflictItemImpl implements _ConflictItem {
  const _$ConflictItemImpl({
    required this.conflictId,
    required this.vaultPath,
    this.mineHash,
    this.theirsHash,
    this.theirsContent = '',
    this.conflictCopyPath,
    this.status,
    this.createdAt,
  });

  factory _$ConflictItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConflictItemImplFromJson(json);

  @override
  final int conflictId;
  @override
  final String vaultPath;
  @override
  final String? mineHash;
  @override
  final String? theirsHash;
  @override
  @JsonKey()
  final String theirsContent;
  @override
  final String? conflictCopyPath;
  @override
  final String? status;
  @override
  final String? createdAt;

  @override
  String toString() {
    return 'ConflictItem(conflictId: $conflictId, vaultPath: $vaultPath, mineHash: $mineHash, theirsHash: $theirsHash, theirsContent: $theirsContent, conflictCopyPath: $conflictCopyPath, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConflictItemImpl &&
            (identical(other.conflictId, conflictId) ||
                other.conflictId == conflictId) &&
            (identical(other.vaultPath, vaultPath) ||
                other.vaultPath == vaultPath) &&
            (identical(other.mineHash, mineHash) ||
                other.mineHash == mineHash) &&
            (identical(other.theirsHash, theirsHash) ||
                other.theirsHash == theirsHash) &&
            (identical(other.theirsContent, theirsContent) ||
                other.theirsContent == theirsContent) &&
            (identical(other.conflictCopyPath, conflictCopyPath) ||
                other.conflictCopyPath == conflictCopyPath) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    conflictId,
    vaultPath,
    mineHash,
    theirsHash,
    theirsContent,
    conflictCopyPath,
    status,
    createdAt,
  );

  /// Create a copy of ConflictItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConflictItemImplCopyWith<_$ConflictItemImpl> get copyWith =>
      __$$ConflictItemImplCopyWithImpl<_$ConflictItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConflictItemImplToJson(this);
  }
}

abstract class _ConflictItem implements ConflictItem {
  const factory _ConflictItem({
    required final int conflictId,
    required final String vaultPath,
    final String? mineHash,
    final String? theirsHash,
    final String theirsContent,
    final String? conflictCopyPath,
    final String? status,
    final String? createdAt,
  }) = _$ConflictItemImpl;

  factory _ConflictItem.fromJson(Map<String, dynamic> json) =
      _$ConflictItemImpl.fromJson;

  @override
  int get conflictId;
  @override
  String get vaultPath;
  @override
  String? get mineHash;
  @override
  String? get theirsHash;
  @override
  String get theirsContent;
  @override
  String? get conflictCopyPath;
  @override
  String? get status;
  @override
  String? get createdAt;

  /// Create a copy of ConflictItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConflictItemImplCopyWith<_$ConflictItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConflictResolvePayload _$ConflictResolvePayloadFromJson(
  Map<String, dynamic> json,
) {
  return _ConflictResolvePayload.fromJson(json);
}

/// @nodoc
mixin _$ConflictResolvePayload {
  String get strategy => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;

  /// Serializes this ConflictResolvePayload to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConflictResolvePayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConflictResolvePayloadCopyWith<ConflictResolvePayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConflictResolvePayloadCopyWith<$Res> {
  factory $ConflictResolvePayloadCopyWith(
    ConflictResolvePayload value,
    $Res Function(ConflictResolvePayload) then,
  ) = _$ConflictResolvePayloadCopyWithImpl<$Res, ConflictResolvePayload>;
  @useResult
  $Res call({String strategy, String? content});
}

/// @nodoc
class _$ConflictResolvePayloadCopyWithImpl<
  $Res,
  $Val extends ConflictResolvePayload
>
    implements $ConflictResolvePayloadCopyWith<$Res> {
  _$ConflictResolvePayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConflictResolvePayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? strategy = null, Object? content = freezed}) {
    return _then(
      _value.copyWith(
            strategy: null == strategy
                ? _value.strategy
                : strategy // ignore: cast_nullable_to_non_nullable
                      as String,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConflictResolvePayloadImplCopyWith<$Res>
    implements $ConflictResolvePayloadCopyWith<$Res> {
  factory _$$ConflictResolvePayloadImplCopyWith(
    _$ConflictResolvePayloadImpl value,
    $Res Function(_$ConflictResolvePayloadImpl) then,
  ) = __$$ConflictResolvePayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String strategy, String? content});
}

/// @nodoc
class __$$ConflictResolvePayloadImplCopyWithImpl<$Res>
    extends
        _$ConflictResolvePayloadCopyWithImpl<$Res, _$ConflictResolvePayloadImpl>
    implements _$$ConflictResolvePayloadImplCopyWith<$Res> {
  __$$ConflictResolvePayloadImplCopyWithImpl(
    _$ConflictResolvePayloadImpl _value,
    $Res Function(_$ConflictResolvePayloadImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConflictResolvePayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? strategy = null, Object? content = freezed}) {
    return _then(
      _$ConflictResolvePayloadImpl(
        strategy: null == strategy
            ? _value.strategy
            : strategy // ignore: cast_nullable_to_non_nullable
                  as String,
        content: freezed == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConflictResolvePayloadImpl implements _ConflictResolvePayload {
  const _$ConflictResolvePayloadImpl({required this.strategy, this.content});

  factory _$ConflictResolvePayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConflictResolvePayloadImplFromJson(json);

  @override
  final String strategy;
  @override
  final String? content;

  @override
  String toString() {
    return 'ConflictResolvePayload(strategy: $strategy, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConflictResolvePayloadImpl &&
            (identical(other.strategy, strategy) ||
                other.strategy == strategy) &&
            (identical(other.content, content) || other.content == content));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, strategy, content);

  /// Create a copy of ConflictResolvePayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConflictResolvePayloadImplCopyWith<_$ConflictResolvePayloadImpl>
  get copyWith =>
      __$$ConflictResolvePayloadImplCopyWithImpl<_$ConflictResolvePayloadImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConflictResolvePayloadImplToJson(this);
  }
}

abstract class _ConflictResolvePayload implements ConflictResolvePayload {
  const factory _ConflictResolvePayload({
    required final String strategy,
    final String? content,
  }) = _$ConflictResolvePayloadImpl;

  factory _ConflictResolvePayload.fromJson(Map<String, dynamic> json) =
      _$ConflictResolvePayloadImpl.fromJson;

  @override
  String get strategy;
  @override
  String? get content;

  /// Create a copy of ConflictResolvePayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConflictResolvePayloadImplCopyWith<_$ConflictResolvePayloadImpl>
  get copyWith => throw _privateConstructorUsedError;
}

VaultPushResult _$VaultPushResultFromJson(Map<String, dynamic> json) {
  return _VaultPushResult.fromJson(json);
}

/// @nodoc
mixin _$VaultPushResult {
  String get outcome => throw _privateConstructorUsedError;
  VaultFileData? get data => throw _privateConstructorUsedError;
  ConflictView? get conflict => throw _privateConstructorUsedError;

  /// Serializes this VaultPushResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VaultPushResultCopyWith<VaultPushResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VaultPushResultCopyWith<$Res> {
  factory $VaultPushResultCopyWith(
    VaultPushResult value,
    $Res Function(VaultPushResult) then,
  ) = _$VaultPushResultCopyWithImpl<$Res, VaultPushResult>;
  @useResult
  $Res call({String outcome, VaultFileData? data, ConflictView? conflict});

  $VaultFileDataCopyWith<$Res>? get data;
  $ConflictViewCopyWith<$Res>? get conflict;
}

/// @nodoc
class _$VaultPushResultCopyWithImpl<$Res, $Val extends VaultPushResult>
    implements $VaultPushResultCopyWith<$Res> {
  _$VaultPushResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? outcome = null,
    Object? data = freezed,
    Object? conflict = freezed,
  }) {
    return _then(
      _value.copyWith(
            outcome: null == outcome
                ? _value.outcome
                : outcome // ignore: cast_nullable_to_non_nullable
                      as String,
            data: freezed == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as VaultFileData?,
            conflict: freezed == conflict
                ? _value.conflict
                : conflict // ignore: cast_nullable_to_non_nullable
                      as ConflictView?,
          )
          as $Val,
    );
  }

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VaultFileDataCopyWith<$Res>? get data {
    if (_value.data == null) {
      return null;
    }

    return $VaultFileDataCopyWith<$Res>(_value.data!, (value) {
      return _then(_value.copyWith(data: value) as $Val);
    });
  }

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConflictViewCopyWith<$Res>? get conflict {
    if (_value.conflict == null) {
      return null;
    }

    return $ConflictViewCopyWith<$Res>(_value.conflict!, (value) {
      return _then(_value.copyWith(conflict: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$VaultPushResultImplCopyWith<$Res>
    implements $VaultPushResultCopyWith<$Res> {
  factory _$$VaultPushResultImplCopyWith(
    _$VaultPushResultImpl value,
    $Res Function(_$VaultPushResultImpl) then,
  ) = __$$VaultPushResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String outcome, VaultFileData? data, ConflictView? conflict});

  @override
  $VaultFileDataCopyWith<$Res>? get data;
  @override
  $ConflictViewCopyWith<$Res>? get conflict;
}

/// @nodoc
class __$$VaultPushResultImplCopyWithImpl<$Res>
    extends _$VaultPushResultCopyWithImpl<$Res, _$VaultPushResultImpl>
    implements _$$VaultPushResultImplCopyWith<$Res> {
  __$$VaultPushResultImplCopyWithImpl(
    _$VaultPushResultImpl _value,
    $Res Function(_$VaultPushResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? outcome = null,
    Object? data = freezed,
    Object? conflict = freezed,
  }) {
    return _then(
      _$VaultPushResultImpl(
        outcome: null == outcome
            ? _value.outcome
            : outcome // ignore: cast_nullable_to_non_nullable
                  as String,
        data: freezed == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as VaultFileData?,
        conflict: freezed == conflict
            ? _value.conflict
            : conflict // ignore: cast_nullable_to_non_nullable
                  as ConflictView?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VaultPushResultImpl implements _VaultPushResult {
  const _$VaultPushResultImpl({
    required this.outcome,
    this.data,
    this.conflict,
  });

  factory _$VaultPushResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$VaultPushResultImplFromJson(json);

  @override
  final String outcome;
  @override
  final VaultFileData? data;
  @override
  final ConflictView? conflict;

  @override
  String toString() {
    return 'VaultPushResult(outcome: $outcome, data: $data, conflict: $conflict)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VaultPushResultImpl &&
            (identical(other.outcome, outcome) || other.outcome == outcome) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.conflict, conflict) ||
                other.conflict == conflict));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, outcome, data, conflict);

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VaultPushResultImplCopyWith<_$VaultPushResultImpl> get copyWith =>
      __$$VaultPushResultImplCopyWithImpl<_$VaultPushResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VaultPushResultImplToJson(this);
  }
}

abstract class _VaultPushResult implements VaultPushResult {
  const factory _VaultPushResult({
    required final String outcome,
    final VaultFileData? data,
    final ConflictView? conflict,
  }) = _$VaultPushResultImpl;

  factory _VaultPushResult.fromJson(Map<String, dynamic> json) =
      _$VaultPushResultImpl.fromJson;

  @override
  String get outcome;
  @override
  VaultFileData? get data;
  @override
  ConflictView? get conflict;

  /// Create a copy of VaultPushResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VaultPushResultImplCopyWith<_$VaultPushResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AttachmentUploadResult _$AttachmentUploadResultFromJson(
  Map<String, dynamic> json,
) {
  return _AttachmentUploadResult.fromJson(json);
}

/// @nodoc
mixin _$AttachmentUploadResult {
  String get hash => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;

  /// Serializes this AttachmentUploadResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AttachmentUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttachmentUploadResultCopyWith<AttachmentUploadResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttachmentUploadResultCopyWith<$Res> {
  factory $AttachmentUploadResultCopyWith(
    AttachmentUploadResult value,
    $Res Function(AttachmentUploadResult) then,
  ) = _$AttachmentUploadResultCopyWithImpl<$Res, AttachmentUploadResult>;
  @useResult
  $Res call({String hash, int size, String path});
}

/// @nodoc
class _$AttachmentUploadResultCopyWithImpl<
  $Res,
  $Val extends AttachmentUploadResult
>
    implements $AttachmentUploadResultCopyWith<$Res> {
  _$AttachmentUploadResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttachmentUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? hash = null, Object? size = null, Object? path = null}) {
    return _then(
      _value.copyWith(
            hash: null == hash
                ? _value.hash
                : hash // ignore: cast_nullable_to_non_nullable
                      as String,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttachmentUploadResultImplCopyWith<$Res>
    implements $AttachmentUploadResultCopyWith<$Res> {
  factory _$$AttachmentUploadResultImplCopyWith(
    _$AttachmentUploadResultImpl value,
    $Res Function(_$AttachmentUploadResultImpl) then,
  ) = __$$AttachmentUploadResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String hash, int size, String path});
}

/// @nodoc
class __$$AttachmentUploadResultImplCopyWithImpl<$Res>
    extends
        _$AttachmentUploadResultCopyWithImpl<$Res, _$AttachmentUploadResultImpl>
    implements _$$AttachmentUploadResultImplCopyWith<$Res> {
  __$$AttachmentUploadResultImplCopyWithImpl(
    _$AttachmentUploadResultImpl _value,
    $Res Function(_$AttachmentUploadResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttachmentUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? hash = null, Object? size = null, Object? path = null}) {
    return _then(
      _$AttachmentUploadResultImpl(
        hash: null == hash
            ? _value.hash
            : hash // ignore: cast_nullable_to_non_nullable
                  as String,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttachmentUploadResultImpl implements _AttachmentUploadResult {
  const _$AttachmentUploadResultImpl({
    required this.hash,
    required this.size,
    required this.path,
  });

  factory _$AttachmentUploadResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttachmentUploadResultImplFromJson(json);

  @override
  final String hash;
  @override
  final int size;
  @override
  final String path;

  @override
  String toString() {
    return 'AttachmentUploadResult(hash: $hash, size: $size, path: $path)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttachmentUploadResultImpl &&
            (identical(other.hash, hash) || other.hash == hash) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.path, path) || other.path == path));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, hash, size, path);

  /// Create a copy of AttachmentUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttachmentUploadResultImplCopyWith<_$AttachmentUploadResultImpl>
  get copyWith =>
      __$$AttachmentUploadResultImplCopyWithImpl<_$AttachmentUploadResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AttachmentUploadResultImplToJson(this);
  }
}

abstract class _AttachmentUploadResult implements AttachmentUploadResult {
  const factory _AttachmentUploadResult({
    required final String hash,
    required final int size,
    required final String path,
  }) = _$AttachmentUploadResultImpl;

  factory _AttachmentUploadResult.fromJson(Map<String, dynamic> json) =
      _$AttachmentUploadResultImpl.fromJson;

  @override
  String get hash;
  @override
  int get size;
  @override
  String get path;

  /// Create a copy of AttachmentUploadResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttachmentUploadResultImplCopyWith<_$AttachmentUploadResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}
