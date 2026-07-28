// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flashcard_mode_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FlashcardModeState {
  bool get isStarted;
  bool get isFinished;
  Word? get currentWord;
  int get currentIndex;
  int get total;
  bool get isFlipped;
  int get correctCount;
  bool get isSubmitting;
  String? get errorMessage;

  /// Create a copy of FlashcardModeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FlashcardModeStateCopyWith<FlashcardModeState> get copyWith =>
      _$FlashcardModeStateCopyWithImpl<FlashcardModeState>(
          this as FlashcardModeState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FlashcardModeState &&
            (identical(other.isStarted, isStarted) ||
                other.isStarted == isStarted) &&
            (identical(other.isFinished, isFinished) ||
                other.isFinished == isFinished) &&
            (identical(other.currentWord, currentWord) ||
                other.currentWord == currentWord) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.isFlipped, isFlipped) ||
                other.isFlipped == isFlipped) &&
            (identical(other.correctCount, correctCount) ||
                other.correctCount == correctCount) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isStarted,
      isFinished,
      currentWord,
      currentIndex,
      total,
      isFlipped,
      correctCount,
      isSubmitting,
      errorMessage);

  @override
  String toString() {
    return 'FlashcardModeState(isStarted: $isStarted, isFinished: $isFinished, currentWord: $currentWord, currentIndex: $currentIndex, total: $total, isFlipped: $isFlipped, correctCount: $correctCount, isSubmitting: $isSubmitting, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class $FlashcardModeStateCopyWith<$Res> {
  factory $FlashcardModeStateCopyWith(
          FlashcardModeState value, $Res Function(FlashcardModeState) _then) =
      _$FlashcardModeStateCopyWithImpl;
  @useResult
  $Res call(
      {bool isStarted,
      bool isFinished,
      Word? currentWord,
      int currentIndex,
      int total,
      bool isFlipped,
      int correctCount,
      bool isSubmitting,
      String? errorMessage});

  $WordCopyWith<$Res>? get currentWord;
}

/// @nodoc
class _$FlashcardModeStateCopyWithImpl<$Res>
    implements $FlashcardModeStateCopyWith<$Res> {
  _$FlashcardModeStateCopyWithImpl(this._self, this._then);

  final FlashcardModeState _self;
  final $Res Function(FlashcardModeState) _then;

  /// Create a copy of FlashcardModeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isStarted = null,
    Object? isFinished = null,
    Object? currentWord = freezed,
    Object? currentIndex = null,
    Object? total = null,
    Object? isFlipped = null,
    Object? correctCount = null,
    Object? isSubmitting = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_self.copyWith(
      isStarted: null == isStarted
          ? _self.isStarted
          : isStarted // ignore: cast_nullable_to_non_nullable
              as bool,
      isFinished: null == isFinished
          ? _self.isFinished
          : isFinished // ignore: cast_nullable_to_non_nullable
              as bool,
      currentWord: freezed == currentWord
          ? _self.currentWord
          : currentWord // ignore: cast_nullable_to_non_nullable
              as Word?,
      currentIndex: null == currentIndex
          ? _self.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      isFlipped: null == isFlipped
          ? _self.isFlipped
          : isFlipped // ignore: cast_nullable_to_non_nullable
              as bool,
      correctCount: null == correctCount
          ? _self.correctCount
          : correctCount // ignore: cast_nullable_to_non_nullable
              as int,
      isSubmitting: null == isSubmitting
          ? _self.isSubmitting
          : isSubmitting // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of FlashcardModeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WordCopyWith<$Res>? get currentWord {
    if (_self.currentWord == null) {
      return null;
    }

    return $WordCopyWith<$Res>(_self.currentWord!, (value) {
      return _then(_self.copyWith(currentWord: value));
    });
  }
}

/// Adds pattern-matching-related methods to [FlashcardModeState].
extension FlashcardModeStatePatterns on FlashcardModeState {
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
    TResult Function(_FlashcardModeState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FlashcardModeState() when $default != null:
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
    TResult Function(_FlashcardModeState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardModeState():
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
    TResult? Function(_FlashcardModeState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardModeState() when $default != null:
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
    TResult Function(
            bool isStarted,
            bool isFinished,
            Word? currentWord,
            int currentIndex,
            int total,
            bool isFlipped,
            int correctCount,
            bool isSubmitting,
            String? errorMessage)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FlashcardModeState() when $default != null:
        return $default(
            _that.isStarted,
            _that.isFinished,
            _that.currentWord,
            _that.currentIndex,
            _that.total,
            _that.isFlipped,
            _that.correctCount,
            _that.isSubmitting,
            _that.errorMessage);
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
    TResult Function(
            bool isStarted,
            bool isFinished,
            Word? currentWord,
            int currentIndex,
            int total,
            bool isFlipped,
            int correctCount,
            bool isSubmitting,
            String? errorMessage)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardModeState():
        return $default(
            _that.isStarted,
            _that.isFinished,
            _that.currentWord,
            _that.currentIndex,
            _that.total,
            _that.isFlipped,
            _that.correctCount,
            _that.isSubmitting,
            _that.errorMessage);
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
    TResult? Function(
            bool isStarted,
            bool isFinished,
            Word? currentWord,
            int currentIndex,
            int total,
            bool isFlipped,
            int correctCount,
            bool isSubmitting,
            String? errorMessage)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FlashcardModeState() when $default != null:
        return $default(
            _that.isStarted,
            _that.isFinished,
            _that.currentWord,
            _that.currentIndex,
            _that.total,
            _that.isFlipped,
            _that.correctCount,
            _that.isSubmitting,
            _that.errorMessage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FlashcardModeState implements FlashcardModeState {
  const _FlashcardModeState(
      {required this.isStarted,
      required this.isFinished,
      this.currentWord,
      required this.currentIndex,
      required this.total,
      required this.isFlipped,
      required this.correctCount,
      this.isSubmitting = false,
      this.errorMessage});

  @override
  final bool isStarted;
  @override
  final bool isFinished;
  @override
  final Word? currentWord;
  @override
  final int currentIndex;
  @override
  final int total;
  @override
  final bool isFlipped;
  @override
  final int correctCount;
  @override
  @JsonKey()
  final bool isSubmitting;
  @override
  final String? errorMessage;

  /// Create a copy of FlashcardModeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FlashcardModeStateCopyWith<_FlashcardModeState> get copyWith =>
      __$FlashcardModeStateCopyWithImpl<_FlashcardModeState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FlashcardModeState &&
            (identical(other.isStarted, isStarted) ||
                other.isStarted == isStarted) &&
            (identical(other.isFinished, isFinished) ||
                other.isFinished == isFinished) &&
            (identical(other.currentWord, currentWord) ||
                other.currentWord == currentWord) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.isFlipped, isFlipped) ||
                other.isFlipped == isFlipped) &&
            (identical(other.correctCount, correctCount) ||
                other.correctCount == correctCount) &&
            (identical(other.isSubmitting, isSubmitting) ||
                other.isSubmitting == isSubmitting) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isStarted,
      isFinished,
      currentWord,
      currentIndex,
      total,
      isFlipped,
      correctCount,
      isSubmitting,
      errorMessage);

  @override
  String toString() {
    return 'FlashcardModeState(isStarted: $isStarted, isFinished: $isFinished, currentWord: $currentWord, currentIndex: $currentIndex, total: $total, isFlipped: $isFlipped, correctCount: $correctCount, isSubmitting: $isSubmitting, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class _$FlashcardModeStateCopyWith<$Res>
    implements $FlashcardModeStateCopyWith<$Res> {
  factory _$FlashcardModeStateCopyWith(
          _FlashcardModeState value, $Res Function(_FlashcardModeState) _then) =
      __$FlashcardModeStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool isStarted,
      bool isFinished,
      Word? currentWord,
      int currentIndex,
      int total,
      bool isFlipped,
      int correctCount,
      bool isSubmitting,
      String? errorMessage});

  @override
  $WordCopyWith<$Res>? get currentWord;
}

/// @nodoc
class __$FlashcardModeStateCopyWithImpl<$Res>
    implements _$FlashcardModeStateCopyWith<$Res> {
  __$FlashcardModeStateCopyWithImpl(this._self, this._then);

  final _FlashcardModeState _self;
  final $Res Function(_FlashcardModeState) _then;

  /// Create a copy of FlashcardModeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isStarted = null,
    Object? isFinished = null,
    Object? currentWord = freezed,
    Object? currentIndex = null,
    Object? total = null,
    Object? isFlipped = null,
    Object? correctCount = null,
    Object? isSubmitting = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_FlashcardModeState(
      isStarted: null == isStarted
          ? _self.isStarted
          : isStarted // ignore: cast_nullable_to_non_nullable
              as bool,
      isFinished: null == isFinished
          ? _self.isFinished
          : isFinished // ignore: cast_nullable_to_non_nullable
              as bool,
      currentWord: freezed == currentWord
          ? _self.currentWord
          : currentWord // ignore: cast_nullable_to_non_nullable
              as Word?,
      currentIndex: null == currentIndex
          ? _self.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      isFlipped: null == isFlipped
          ? _self.isFlipped
          : isFlipped // ignore: cast_nullable_to_non_nullable
              as bool,
      correctCount: null == correctCount
          ? _self.correctCount
          : correctCount // ignore: cast_nullable_to_non_nullable
              as int,
      isSubmitting: null == isSubmitting
          ? _self.isSubmitting
          : isSubmitting // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of FlashcardModeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WordCopyWith<$Res>? get currentWord {
    if (_self.currentWord == null) {
      return null;
    }

    return $WordCopyWith<$Res>(_self.currentWord!, (value) {
      return _then(_self.copyWith(currentWord: value));
    });
  }
}

// dart format on
