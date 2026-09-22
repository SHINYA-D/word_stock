import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/error/failure.dart';
import '../../domain/entities/sample.dart';

part 'sample_state.freezed.dart';

@freezed
abstract class SampleState with _$SampleState {
  const factory SampleState({
    required AsyncValue<List<Sample>> samples,
    /// 操作の失敗を画面へ伝える（画面はこの変化を監視してスナックバー等を出す）
    Failure? operationFailure,
  }) = _SampleState;

  factory SampleState.loading() =>
      const SampleState(samples: AsyncValue.loading());
}
