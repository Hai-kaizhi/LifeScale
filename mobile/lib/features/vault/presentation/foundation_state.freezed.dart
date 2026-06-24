// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'foundation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$FoundationState {
  String get loginMessage => throw _privateConstructorUsedError;
  String get deviceMessage => throw _privateConstructorUsedError;
  String get changesMessage => throw _privateConstructorUsedError;
  String get cacheMessage => throw _privateConstructorUsedError;
  bool get busy => throw _privateConstructorUsedError;

  /// Create a copy of FoundationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FoundationStateCopyWith<FoundationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FoundationStateCopyWith<$Res> {
  factory $FoundationStateCopyWith(
    FoundationState value,
    $Res Function(FoundationState) then,
  ) = _$FoundationStateCopyWithImpl<$Res, FoundationState>;
  @useResult
  $Res call({
    String loginMessage,
    String deviceMessage,
    String changesMessage,
    String cacheMessage,
    bool busy,
  });
}

/// @nodoc
class _$FoundationStateCopyWithImpl<$Res, $Val extends FoundationState>
    implements $FoundationStateCopyWith<$Res> {
  _$FoundationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FoundationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loginMessage = null,
    Object? deviceMessage = null,
    Object? changesMessage = null,
    Object? cacheMessage = null,
    Object? busy = null,
  }) {
    return _then(
      _value.copyWith(
            loginMessage: null == loginMessage
                ? _value.loginMessage
                : loginMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            deviceMessage: null == deviceMessage
                ? _value.deviceMessage
                : deviceMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            changesMessage: null == changesMessage
                ? _value.changesMessage
                : changesMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            cacheMessage: null == cacheMessage
                ? _value.cacheMessage
                : cacheMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            busy: null == busy
                ? _value.busy
                : busy // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FoundationStateImplCopyWith<$Res>
    implements $FoundationStateCopyWith<$Res> {
  factory _$$FoundationStateImplCopyWith(
    _$FoundationStateImpl value,
    $Res Function(_$FoundationStateImpl) then,
  ) = __$$FoundationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String loginMessage,
    String deviceMessage,
    String changesMessage,
    String cacheMessage,
    bool busy,
  });
}

/// @nodoc
class __$$FoundationStateImplCopyWithImpl<$Res>
    extends _$FoundationStateCopyWithImpl<$Res, _$FoundationStateImpl>
    implements _$$FoundationStateImplCopyWith<$Res> {
  __$$FoundationStateImplCopyWithImpl(
    _$FoundationStateImpl _value,
    $Res Function(_$FoundationStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FoundationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loginMessage = null,
    Object? deviceMessage = null,
    Object? changesMessage = null,
    Object? cacheMessage = null,
    Object? busy = null,
  }) {
    return _then(
      _$FoundationStateImpl(
        loginMessage: null == loginMessage
            ? _value.loginMessage
            : loginMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        deviceMessage: null == deviceMessage
            ? _value.deviceMessage
            : deviceMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        changesMessage: null == changesMessage
            ? _value.changesMessage
            : changesMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        cacheMessage: null == cacheMessage
            ? _value.cacheMessage
            : cacheMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        busy: null == busy
            ? _value.busy
            : busy // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$FoundationStateImpl implements _FoundationState {
  const _$FoundationStateImpl({
    this.loginMessage = '',
    this.deviceMessage = '',
    this.changesMessage = '',
    this.cacheMessage = '',
    this.busy = false,
  });

  @override
  @JsonKey()
  final String loginMessage;
  @override
  @JsonKey()
  final String deviceMessage;
  @override
  @JsonKey()
  final String changesMessage;
  @override
  @JsonKey()
  final String cacheMessage;
  @override
  @JsonKey()
  final bool busy;

  @override
  String toString() {
    return 'FoundationState(loginMessage: $loginMessage, deviceMessage: $deviceMessage, changesMessage: $changesMessage, cacheMessage: $cacheMessage, busy: $busy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FoundationStateImpl &&
            (identical(other.loginMessage, loginMessage) ||
                other.loginMessage == loginMessage) &&
            (identical(other.deviceMessage, deviceMessage) ||
                other.deviceMessage == deviceMessage) &&
            (identical(other.changesMessage, changesMessage) ||
                other.changesMessage == changesMessage) &&
            (identical(other.cacheMessage, cacheMessage) ||
                other.cacheMessage == cacheMessage) &&
            (identical(other.busy, busy) || other.busy == busy));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    loginMessage,
    deviceMessage,
    changesMessage,
    cacheMessage,
    busy,
  );

  /// Create a copy of FoundationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FoundationStateImplCopyWith<_$FoundationStateImpl> get copyWith =>
      __$$FoundationStateImplCopyWithImpl<_$FoundationStateImpl>(
        this,
        _$identity,
      );
}

abstract class _FoundationState implements FoundationState {
  const factory _FoundationState({
    final String loginMessage,
    final String deviceMessage,
    final String changesMessage,
    final String cacheMessage,
    final bool busy,
  }) = _$FoundationStateImpl;

  @override
  String get loginMessage;
  @override
  String get deviceMessage;
  @override
  String get changesMessage;
  @override
  String get cacheMessage;
  @override
  bool get busy;

  /// Create a copy of FoundationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FoundationStateImplCopyWith<_$FoundationStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
