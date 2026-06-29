// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_doc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ReviewEntry {
  String get questionId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;

  /// Create a copy of ReviewEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewEntryCopyWith<ReviewEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewEntryCopyWith<$Res> {
  factory $ReviewEntryCopyWith(
    ReviewEntry value,
    $Res Function(ReviewEntry) then,
  ) = _$ReviewEntryCopyWithImpl<$Res, ReviewEntry>;
  @useResult
  $Res call({String questionId, String title, String content});
}

/// @nodoc
class _$ReviewEntryCopyWithImpl<$Res, $Val extends ReviewEntry>
    implements $ReviewEntryCopyWith<$Res> {
  _$ReviewEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? title = null,
    Object? content = null,
  }) {
    return _then(
      _value.copyWith(
            questionId: null == questionId
                ? _value.questionId
                : questionId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewEntryImplCopyWith<$Res>
    implements $ReviewEntryCopyWith<$Res> {
  factory _$$ReviewEntryImplCopyWith(
    _$ReviewEntryImpl value,
    $Res Function(_$ReviewEntryImpl) then,
  ) = __$$ReviewEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String questionId, String title, String content});
}

/// @nodoc
class __$$ReviewEntryImplCopyWithImpl<$Res>
    extends _$ReviewEntryCopyWithImpl<$Res, _$ReviewEntryImpl>
    implements _$$ReviewEntryImplCopyWith<$Res> {
  __$$ReviewEntryImplCopyWithImpl(
    _$ReviewEntryImpl _value,
    $Res Function(_$ReviewEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? title = null,
    Object? content = null,
  }) {
    return _then(
      _$ReviewEntryImpl(
        questionId: null == questionId
            ? _value.questionId
            : questionId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ReviewEntryImpl implements _ReviewEntry {
  const _$ReviewEntryImpl({
    required this.questionId,
    required this.title,
    this.content = '',
  });

  @override
  final String questionId;
  @override
  final String title;
  @override
  @JsonKey()
  final String content;

  @override
  String toString() {
    return 'ReviewEntry(questionId: $questionId, title: $title, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewEntryImpl &&
            (identical(other.questionId, questionId) ||
                other.questionId == questionId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content));
  }

  @override
  int get hashCode => Object.hash(runtimeType, questionId, title, content);

  /// Create a copy of ReviewEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewEntryImplCopyWith<_$ReviewEntryImpl> get copyWith =>
      __$$ReviewEntryImplCopyWithImpl<_$ReviewEntryImpl>(this, _$identity);
}

abstract class _ReviewEntry implements ReviewEntry {
  const factory _ReviewEntry({
    required final String questionId,
    required final String title,
    final String content,
  }) = _$ReviewEntryImpl;

  @override
  String get questionId;
  @override
  String get title;
  @override
  String get content;

  /// Create a copy of ReviewEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewEntryImplCopyWith<_$ReviewEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DailyDocModel {
  String get title => throw _privateConstructorUsedError;
  String? get focus => throw _privateConstructorUsedError;
  List<Schedule> get schedules => throw _privateConstructorUsedError;
  List<QuickNote> get quickNotes => throw _privateConstructorUsedError;
  List<ReviewEntry> get review => throw _privateConstructorUsedError;

  /// Create a copy of DailyDocModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyDocModelCopyWith<DailyDocModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyDocModelCopyWith<$Res> {
  factory $DailyDocModelCopyWith(
    DailyDocModel value,
    $Res Function(DailyDocModel) then,
  ) = _$DailyDocModelCopyWithImpl<$Res, DailyDocModel>;
  @useResult
  $Res call({
    String title,
    String? focus,
    List<Schedule> schedules,
    List<QuickNote> quickNotes,
    List<ReviewEntry> review,
  });
}

/// @nodoc
class _$DailyDocModelCopyWithImpl<$Res, $Val extends DailyDocModel>
    implements $DailyDocModelCopyWith<$Res> {
  _$DailyDocModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyDocModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? focus = freezed,
    Object? schedules = null,
    Object? quickNotes = null,
    Object? review = null,
  }) {
    return _then(
      _value.copyWith(
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            focus: freezed == focus
                ? _value.focus
                : focus // ignore: cast_nullable_to_non_nullable
                      as String?,
            schedules: null == schedules
                ? _value.schedules
                : schedules // ignore: cast_nullable_to_non_nullable
                      as List<Schedule>,
            quickNotes: null == quickNotes
                ? _value.quickNotes
                : quickNotes // ignore: cast_nullable_to_non_nullable
                      as List<QuickNote>,
            review: null == review
                ? _value.review
                : review // ignore: cast_nullable_to_non_nullable
                      as List<ReviewEntry>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyDocModelImplCopyWith<$Res>
    implements $DailyDocModelCopyWith<$Res> {
  factory _$$DailyDocModelImplCopyWith(
    _$DailyDocModelImpl value,
    $Res Function(_$DailyDocModelImpl) then,
  ) = __$$DailyDocModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String title,
    String? focus,
    List<Schedule> schedules,
    List<QuickNote> quickNotes,
    List<ReviewEntry> review,
  });
}

/// @nodoc
class __$$DailyDocModelImplCopyWithImpl<$Res>
    extends _$DailyDocModelCopyWithImpl<$Res, _$DailyDocModelImpl>
    implements _$$DailyDocModelImplCopyWith<$Res> {
  __$$DailyDocModelImplCopyWithImpl(
    _$DailyDocModelImpl _value,
    $Res Function(_$DailyDocModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyDocModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? focus = freezed,
    Object? schedules = null,
    Object? quickNotes = null,
    Object? review = null,
  }) {
    return _then(
      _$DailyDocModelImpl(
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        focus: freezed == focus
            ? _value.focus
            : focus // ignore: cast_nullable_to_non_nullable
                  as String?,
        schedules: null == schedules
            ? _value._schedules
            : schedules // ignore: cast_nullable_to_non_nullable
                  as List<Schedule>,
        quickNotes: null == quickNotes
            ? _value._quickNotes
            : quickNotes // ignore: cast_nullable_to_non_nullable
                  as List<QuickNote>,
        review: null == review
            ? _value._review
            : review // ignore: cast_nullable_to_non_nullable
                  as List<ReviewEntry>,
      ),
    );
  }
}

/// @nodoc

class _$DailyDocModelImpl implements _DailyDocModel {
  const _$DailyDocModelImpl({
    required this.title,
    this.focus,
    final List<Schedule> schedules = const <Schedule>[],
    final List<QuickNote> quickNotes = const <QuickNote>[],
    final List<ReviewEntry> review = const <ReviewEntry>[],
  }) : _schedules = schedules,
       _quickNotes = quickNotes,
       _review = review;

  @override
  final String title;
  @override
  final String? focus;
  final List<Schedule> _schedules;
  @override
  @JsonKey()
  List<Schedule> get schedules {
    if (_schedules is EqualUnmodifiableListView) return _schedules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_schedules);
  }

  final List<QuickNote> _quickNotes;
  @override
  @JsonKey()
  List<QuickNote> get quickNotes {
    if (_quickNotes is EqualUnmodifiableListView) return _quickNotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quickNotes);
  }

  final List<ReviewEntry> _review;
  @override
  @JsonKey()
  List<ReviewEntry> get review {
    if (_review is EqualUnmodifiableListView) return _review;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_review);
  }

  @override
  String toString() {
    return 'DailyDocModel(title: $title, focus: $focus, schedules: $schedules, quickNotes: $quickNotes, review: $review)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyDocModelImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.focus, focus) || other.focus == focus) &&
            const DeepCollectionEquality().equals(
              other._schedules,
              _schedules,
            ) &&
            const DeepCollectionEquality().equals(
              other._quickNotes,
              _quickNotes,
            ) &&
            const DeepCollectionEquality().equals(other._review, _review));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    title,
    focus,
    const DeepCollectionEquality().hash(_schedules),
    const DeepCollectionEquality().hash(_quickNotes),
    const DeepCollectionEquality().hash(_review),
  );

  /// Create a copy of DailyDocModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyDocModelImplCopyWith<_$DailyDocModelImpl> get copyWith =>
      __$$DailyDocModelImplCopyWithImpl<_$DailyDocModelImpl>(this, _$identity);
}

abstract class _DailyDocModel implements DailyDocModel {
  const factory _DailyDocModel({
    required final String title,
    final String? focus,
    final List<Schedule> schedules,
    final List<QuickNote> quickNotes,
    final List<ReviewEntry> review,
  }) = _$DailyDocModelImpl;

  @override
  String get title;
  @override
  String? get focus;
  @override
  List<Schedule> get schedules;
  @override
  List<QuickNote> get quickNotes;
  @override
  List<ReviewEntry> get review;

  /// Create a copy of DailyDocModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyDocModelImplCopyWith<_$DailyDocModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ParseResult {
  DailyDocModel get model => throw _privateConstructorUsedError;
  bool get dirty => throw _privateConstructorUsedError;

  /// Create a copy of ParseResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ParseResultCopyWith<ParseResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ParseResultCopyWith<$Res> {
  factory $ParseResultCopyWith(
    ParseResult value,
    $Res Function(ParseResult) then,
  ) = _$ParseResultCopyWithImpl<$Res, ParseResult>;
  @useResult
  $Res call({DailyDocModel model, bool dirty});

  $DailyDocModelCopyWith<$Res> get model;
}

/// @nodoc
class _$ParseResultCopyWithImpl<$Res, $Val extends ParseResult>
    implements $ParseResultCopyWith<$Res> {
  _$ParseResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ParseResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? model = null, Object? dirty = null}) {
    return _then(
      _value.copyWith(
            model: null == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as DailyDocModel,
            dirty: null == dirty
                ? _value.dirty
                : dirty // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of ParseResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DailyDocModelCopyWith<$Res> get model {
    return $DailyDocModelCopyWith<$Res>(_value.model, (value) {
      return _then(_value.copyWith(model: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ParseResultImplCopyWith<$Res>
    implements $ParseResultCopyWith<$Res> {
  factory _$$ParseResultImplCopyWith(
    _$ParseResultImpl value,
    $Res Function(_$ParseResultImpl) then,
  ) = __$$ParseResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DailyDocModel model, bool dirty});

  @override
  $DailyDocModelCopyWith<$Res> get model;
}

/// @nodoc
class __$$ParseResultImplCopyWithImpl<$Res>
    extends _$ParseResultCopyWithImpl<$Res, _$ParseResultImpl>
    implements _$$ParseResultImplCopyWith<$Res> {
  __$$ParseResultImplCopyWithImpl(
    _$ParseResultImpl _value,
    $Res Function(_$ParseResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ParseResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? model = null, Object? dirty = null}) {
    return _then(
      _$ParseResultImpl(
        model: null == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as DailyDocModel,
        dirty: null == dirty
            ? _value.dirty
            : dirty // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ParseResultImpl implements _ParseResult {
  const _$ParseResultImpl({required this.model, this.dirty = false});

  @override
  final DailyDocModel model;
  @override
  @JsonKey()
  final bool dirty;

  @override
  String toString() {
    return 'ParseResult(model: $model, dirty: $dirty)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ParseResultImpl &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.dirty, dirty) || other.dirty == dirty));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model, dirty);

  /// Create a copy of ParseResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ParseResultImplCopyWith<_$ParseResultImpl> get copyWith =>
      __$$ParseResultImplCopyWithImpl<_$ParseResultImpl>(this, _$identity);
}

abstract class _ParseResult implements ParseResult {
  const factory _ParseResult({
    required final DailyDocModel model,
    final bool dirty,
  }) = _$ParseResultImpl;

  @override
  DailyDocModel get model;
  @override
  bool get dirty;

  /// Create a copy of ParseResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ParseResultImplCopyWith<_$ParseResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
