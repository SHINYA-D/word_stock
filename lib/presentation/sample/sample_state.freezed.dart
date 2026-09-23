// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sample_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SampleState {
  AsyncValue<List<Sample>> get samples;

  /// 操作の失敗を画面へ伝える（画面はこの変化を監視してスナックバー等を出す）
  Failure? get operationFailure;

  /// Create a copy of SampleState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SampleStateCopyWith<SampleState> get copyWith =>
      _$SampleStateCopyWithImpl<SampleState>(this as SampleState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SampleState &&
            (identical(other.samples, samples) || other.samples == samples) &&
            (identical(other.operationFailure, operationFailure) ||
                other.operationFailure == operationFailure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, samples, operationFailure);

  @override
  String toString() {
    return 'SampleState(samples: $samples, operationFailure: $operationFailure)';
  }
}

/// @nodoc
abstract mixin class $SampleStateCopyWith<$Res> {
  factory $SampleStateCopyWith(
          SampleState value, $Res Function(SampleState) _then) =
      _$SampleStateCopyWithImpl;
  @useResult
  $Res call({AsyncValue<List<Sample>> samples, Failure? operationFailure});

  $FailureCopyWith<$Res>? get operationFailure;
}

/// @nodoc
class _$SampleStateCopyWithImpl<$Res> implements $SampleStateCopyWith<$Res> {
  _$SampleStateCopyWithImpl(this._self, this._then);

  final SampleState _self;
  final $Res Function(SampleState) _then;

  /// Create a copy of SampleState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? samples = null,
    Object? operationFailure = freezed,
  }) {
    return _then(_self.copyWith(
      samples: null == samples
          ? _self.samples
          : samples // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<Sample>>,
      operationFailure: freezed == operationFailure
          ? _self.operationFailure
          : operationFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }

  /// Create a copy of SampleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FailureCopyWith<$Res>? get operationFailure {
    if (_self.operationFailure == null) {
      return null;
    }

    return $FailureCopyWith<$Res>(_self.operationFailure!, (value) {
      return _then(_self.copyWith(operationFailure: value));
    });
  }
}

/// Adds pattern-matching-related methods to [SampleState].
extension SampleStatePatterns on SampleState {
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
    TResult Function(_SampleState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SampleState() when $default != null:
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
    TResult Function(_SampleState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SampleState():
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
    TResult? Function(_SampleState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SampleState() when $default != null:
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
            AsyncValue<List<Sample>> samples, Failure? operationFailure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SampleState() when $default != null:
        return $default(_that.samples, _that.operationFailure);
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
            AsyncValue<List<Sample>> samples, Failure? operationFailure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SampleState():
        return $default(_that.samples, _that.operationFailure);
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
            AsyncValue<List<Sample>> samples, Failure? operationFailure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SampleState() when $default != null:
        return $default(_that.samples, _that.operationFailure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SampleState implements SampleState {
  const _SampleState({required this.samples, this.operationFailure});

  @override
  final AsyncValue<List<Sample>> samples;

  /// 操作の失敗を画面へ伝える（画面はこの変化を監視してスナックバー等を出す）
  @override
  final Failure? operationFailure;

  /// Create a copy of SampleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SampleStateCopyWith<_SampleState> get copyWith =>
      __$SampleStateCopyWithImpl<_SampleState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SampleState &&
            (identical(other.samples, samples) || other.samples == samples) &&
            (identical(other.operationFailure, operationFailure) ||
                other.operationFailure == operationFailure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, samples, operationFailure);

  @override
  String toString() {
    return 'SampleState(samples: $samples, operationFailure: $operationFailure)';
  }
}

/// @nodoc
abstract mixin class _$SampleStateCopyWith<$Res>
    implements $SampleStateCopyWith<$Res> {
  factory _$SampleStateCopyWith(
          _SampleState value, $Res Function(_SampleState) _then) =
      __$SampleStateCopyWithImpl;
  @override
  @useResult
  $Res call({AsyncValue<List<Sample>> samples, Failure? operationFailure});

  @override
  $FailureCopyWith<$Res>? get operationFailure;
}

/// @nodoc
class __$SampleStateCopyWithImpl<$Res> implements _$SampleStateCopyWith<$Res> {
  __$SampleStateCopyWithImpl(this._self, this._then);

  final _SampleState _self;
  final $Res Function(_SampleState) _then;

  /// Create a copy of SampleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? samples = null,
    Object? operationFailure = freezed,
  }) {
    return _then(_SampleState(
      samples: null == samples
          ? _self.samples
          : samples // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<Sample>>,
      operationFailure: freezed == operationFailure
          ? _self.operationFailure
          : operationFailure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }

  /// Create a copy of SampleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FailureCopyWith<$Res>? get operationFailure {
    if (_self.operationFailure == null) {
      return null;
    }

    return $FailureCopyWith<$Res>(_self.operationFailure!, (value) {
      return _then(_self.copyWith(operationFailure: value));
    });
  }
}

// dart format on
