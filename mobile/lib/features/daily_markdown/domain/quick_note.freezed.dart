// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quick_note.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$QuickNote {
  String get id => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String get sourceDevice => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get createdAt => throw _privateConstructorUsedError;
  String get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of QuickNote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuickNoteCopyWith<QuickNote> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuickNoteCopyWith<$Res> {
  factory $QuickNoteCopyWith(QuickNote value, $Res Function(QuickNote) then) =
      _$QuickNoteCopyWithImpl<$Res, QuickNote>;
  @useResult
  $Res call({
    String id,
    String date,
    String content,
    String sourceDevice,
    String status,
    String createdAt,
    String updatedAt,
  });
}

/// @nodoc
class _$QuickNoteCopyWithImpl<$Res, $Val extends QuickNote>
    implements $QuickNoteCopyWith<$Res> {
  _$QuickNoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuickNote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? content = null,
    Object? sourceDevice = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceDevice: null == sourceDevice
                ? _value.sourceDevice
                : sourceDevice // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuickNoteImplCopyWith<$Res>
    implements $QuickNoteCopyWith<$Res> {
  factory _$$QuickNoteImplCopyWith(
    _$QuickNoteImpl value,
    $Res Function(_$QuickNoteImpl) then,
  ) = __$$QuickNoteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String date,
    String content,
    String sourceDevice,
    String status,
    String createdAt,
    String updatedAt,
  });
}

/// @nodoc
class __$$QuickNoteImplCopyWithImpl<$Res>
    extends _$QuickNoteCopyWithImpl<$Res, _$QuickNoteImpl>
    implements _$$QuickNoteImplCopyWith<$Res> {
  __$$QuickNoteImplCopyWithImpl(
    _$QuickNoteImpl _value,
    $Res Function(_$QuickNoteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuickNote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? content = null,
    Object? sourceDevice = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$QuickNoteImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceDevice: null == sourceDevice
            ? _value.sourceDevice
            : sourceDevice // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$QuickNoteImpl implements _QuickNote {
  const _$QuickNoteImpl({
    required this.id,
    required this.date,
    required this.content,
    this.sourceDevice = 'desktop',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  @override
  final String date;
  @override
  final String content;
  @override
  @JsonKey()
  final String sourceDevice;
  @override
  @JsonKey()
  final String status;
  @override
  final String createdAt;
  @override
  final String updatedAt;

  @override
  String toString() {
    return 'QuickNote(id: $id, date: $date, content: $content, sourceDevice: $sourceDevice, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuickNoteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.sourceDevice, sourceDevice) ||
                other.sourceDevice == sourceDevice) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    date,
    content,
    sourceDevice,
    status,
    createdAt,
    updatedAt,
  );

  /// Create a copy of QuickNote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuickNoteImplCopyWith<_$QuickNoteImpl> get copyWith =>
      __$$QuickNoteImplCopyWithImpl<_$QuickNoteImpl>(this, _$identity);
}

abstract class _QuickNote implements QuickNote {
  const factory _QuickNote({
    required final String id,
    required final String date,
    required final String content,
    final String sourceDevice,
    final String status,
    required final String createdAt,
    required final String updatedAt,
  }) = _$QuickNoteImpl;

  @override
  String get id;
  @override
  String get date;
  @override
  String get content;
  @override
  String get sourceDevice;
  @override
  String get status;
  @override
  String get createdAt;
  @override
  String get updatedAt;

  /// Create a copy of QuickNote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuickNoteImplCopyWith<_$QuickNoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
