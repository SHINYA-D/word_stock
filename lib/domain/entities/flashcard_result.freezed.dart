// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flashcard_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FlashcardResult {
  String get id;
  String get folderId;
  int get totalCount;
  int get correctCount;
  DateTime get date;
  DateTime get updatedAt;

  /// Create a copy of FlashcardResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FlashcardResultCopyWith<FlashcardResult> get copyWith =>
      _$FlashcardResultCopyWithImpl<FlashcardResult>(
          this as FlashcardResult, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FlashcardResult &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.folderId, folderId) ||
                other.folderId == folderId) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount) &&
            (identical(other.correctCount, correctCount) ||
                other.correctCount == correctCount) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, id, folderId, totalCount, correctCount, date, updatedAt);

  @override
  String toString() {
    return 'FlashcardResult(id: $id, folderId: $folderId, totalCount: $totalCount, correctCount: $correctCount, date: $date, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class $FlashcardResultCopyWith<$Res> {
  factory $FlashcardResultCopyWith(
          FlashcardResult value, $Res Function(FlashcardResult) _then) =
      _$FlashcardResultCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String folderId,
      int totalCount,
      int correctCount,
      DateTime date,
      DateTime updatedAt});
}

/// @nodoc
class _$FlashcardResultCopyWithImpl<$Res>
    implements $FlashcardResultCopyWith<$Res> {
  _$FlashcardResultCopyWithImpl(this._self, this._then);

  final FlashcardResult _self;
  final $Res Function(FlashcardResult) _then;

  /// Create a copy of FlashcardResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? folderId = null,
    Object? totalCount = null,
    Object? correctCount = null,
    Object? date = null,
    Object? updatedAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      folderId: null == folderId
          ? _self.folderId
          : folderId // ignore: cast_nullable_to_non_nullable
              as String,
      totalCount: null == totalCount
          ? _self.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
      correctCount: null == correctCount
          ? _self.correctCount
          : correctCount // ignore: cast_nullable_to_non_nullable
              as int,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [FlashcardResult].
extension FlashcardResultPatterns on FlashcardResult {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_FlashcardResult value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FlashcardResult() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_FlashcardResult value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardResult():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_FlashcardResult value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardResult() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String id, String folderId, int totalCount,
            int correctCount, DateTime date, DateTime updatedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FlashcardResult() when $default != null:
        return $default(_that.id, _that.folderId, _that.totalCount,
            _that.correctCount, _that.date, _that.updatedAt);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String id, String folderId, int totalCount,
            int correctCount, DateTime date, DateTime updatedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardResult():
        return $default(_that.id, _that.folderId, _that.totalCount,
            _that.correctCount, _that.date, _that.updatedAt);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String id, String folderId, int totalCount,
            int correctCount, DateTime date, DateTime updatedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardResult() when $default != null:
        return $default(_that.id, _that.folderId, _that.totalCount,
            _that.correctCount, _that.date, _that.updatedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FlashcardResult extends FlashcardResult {
  const _FlashcardResult(
      {required this.id,
      required this.folderId,
      required this.totalCount,
      required this.correctCount,
      required this.date,
      required this.updatedAt})
      : super._();

  @override
  final String id;
  @override
  final String folderId;
  @override
  final int totalCount;
  @override
  final int correctCount;
  @override
  final DateTime date;
  @override
  final DateTime updatedAt;

  /// Create a copy of FlashcardResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FlashcardResultCopyWith<_FlashcardResult> get copyWith =>
      __$FlashcardResultCopyWithImpl<_FlashcardResult>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FlashcardResult &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.folderId, folderId) ||
                other.folderId == folderId) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount) &&
            (identical(other.correctCount, correctCount) ||
                other.correctCount == correctCount) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, id, folderId, totalCount, correctCount, date, updatedAt);

  @override
  String toString() {
    return 'FlashcardResult(id: $id, folderId: $folderId, totalCount: $totalCount, correctCount: $correctCount, date: $date, updatedAt: $updatedAt)';
  }
}

/// @nodoc
abstract mixin class _$FlashcardResultCopyWith<$Res>
    implements $FlashcardResultCopyWith<$Res> {
  factory _$FlashcardResultCopyWith(
          _FlashcardResult value, $Res Function(_FlashcardResult) _then) =
      __$FlashcardResultCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String folderId,
      int totalCount,
      int correctCount,
      DateTime date,
      DateTime updatedAt});
}

/// @nodoc
class __$FlashcardResultCopyWithImpl<$Res>
    implements _$FlashcardResultCopyWith<$Res> {
  __$FlashcardResultCopyWithImpl(this._self, this._then);

  final _FlashcardResult _self;
  final $Res Function(_FlashcardResult) _then;

  /// Create a copy of FlashcardResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? folderId = null,
    Object? totalCount = null,
    Object? correctCount = null,
    Object? date = null,
    Object? updatedAt = null,
  }) {
    return _then(_FlashcardResult(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      folderId: null == folderId
          ? _self.folderId
          : folderId // ignore: cast_nullable_to_non_nullable
              as String,
      totalCount: null == totalCount
          ? _self.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
      correctCount: null == correctCount
          ? _self.correctCount
          : correctCount // ignore: cast_nullable_to_non_nullable
              as int,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
