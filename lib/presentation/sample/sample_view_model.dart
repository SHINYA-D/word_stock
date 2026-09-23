import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sample_providers.dart';
import 'package:word_stock/presentation/sample/sample_state.dart';

part 'sample_view_model.g.dart';

@riverpod
class SampleViewModel extends _$SampleViewModel {
  late String _userId;

  /// データを変える操作が完了するたびに進める。読み取りの結果が古いかどうかの判定に使う。
  int _revision = 0;

  @override
  SampleState build() {
    Future.microtask(() => _initState());
    return SampleState.loading();
  }

  Future<void> _initState() async {
    _userId = ref.watch(currentUserProvider)?.id ?? '';
    final result = await ref.read(getSamplesUseCaseProvider).call(
          userId: _userId,
        );
    result.fold(
      _applyLoadFailure,
      (samples) {
        state = state.copyWith(
          samples: AsyncValue.data(samples),
        );
      },
    );
  }

  /// 一覧を表示できていないとき（初期読み込み・`ErrorScreen` からの再試行）の失敗の扱い。
  /// 通信・認証エラーは `ErrorScreen` ではなく `NetworkErrorDialog` で伝える（原則-11）。
  /// 初期読み込みと再試行で扱いがずれないよう、両方からこれを呼ぶ。
  void _applyLoadFailure(Failure failure) {
    state = switch (failure) {
      NetworkFailure() || AuthFailure() => state.copyWith(
          samples: const AsyncValue.data([]),
          operationFailure: failure,
        ),
      _ => state.copyWith(
          samples: AsyncValue.error(failure, StackTrace.current),
        ),
    };
  }

  Future<void> refresh() async {
    // 一覧を表示できているとき（プルして更新）は、失敗しても一覧を残す。
    // ErrorScreen からの再試行のときだけ、失敗を ErrorScreen で表示する。
    final hasList = state.samples.hasValue;
    state = hasList ? state.copyWith(operationFailure: null) : state.copyWith(samples: const AsyncLoading());
    final startedAt = _revision;
    final result = await ref.read(getSamplesUseCaseProvider).call(
          userId: _userId,
        );
    // 読み取り中にデータを変える操作が完了していたら、この結果はもう古い。
    // 上書きすると削除したアイテムが一覧に戻ってしまうため捨てる。
    if (_revision != startedAt) return;
    result.fold(
      (failure) {
        if (hasList) {
          // プルして更新。失敗しても一覧はそのまま残し、スナックバーで伝える
          state = state.copyWith(operationFailure: failure);
          return;
        }
        _applyLoadFailure(failure);
      },
      (samples) => state = state.copyWith(samples: AsyncValue.data(samples)),
    );
  }

  /// 作成に成功したら true を返す（画面はそのときだけダイアログを閉じる）
  Future<bool> createSample({required String name}) async {
    state = state.copyWith(operationFailure: null);
    final result = await ref.read(createSampleUseCaseProvider).call(
          userId: _userId,
          name: name,
        );
    return result.fold(
      (failure) {
        state = state.copyWith(operationFailure: failure);
        return false;
      },
      (sample) {
        _revision++;
        final current = state.samples.value ?? [];
        state = state.copyWith(
          samples: AsyncValue.data([...current, sample]),
        );
        return true;
      },
    );
  }

  /// 変更に成功したら true を返す（画面はそのときだけダイアログを閉じる）
  Future<bool> updateSample({
    required String sampleId,
    required String name,
  }) async {
    state = state.copyWith(operationFailure: null);
    final result = await ref.read(updateSampleUseCaseProvider).call(
          userId: _userId,
          sampleId: sampleId,
          name: name,
        );
    return result.fold(
      (failure) {
        state = state.copyWith(operationFailure: failure);
        return false;
      },
      (updated) {
        _revision++;
        final current = state.samples.value ?? [];
        state = state.copyWith(
          samples: AsyncValue.data(
            current.map((s) => s.id == sampleId ? updated : s).toList(),
          ),
        );
        return true;
      },
    );
  }

  Future<void> deleteSample({required String sampleId}) async {
    // 同じ失敗が続いても画面が変化を検知できるよう、操作の前に消しておく
    state = state.copyWith(operationFailure: null);
    final result = await ref.read(deleteSampleUseCaseProvider).call(
          userId: _userId,
          sampleId: sampleId,
        );
    result.fold(
      (failure) => state = state.copyWith(operationFailure: failure),
      (_) {
        _revision++;
        refresh();
      },
    );
  }
}
