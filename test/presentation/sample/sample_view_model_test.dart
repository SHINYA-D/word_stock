import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/application/use_cases/sample/create_sample_use_case.dart';
import 'package:word_stock/application/use_cases/sample/delete_sample_use_case.dart';
import 'package:word_stock/application/use_cases/sample/get_samples_use_case.dart';
import 'package:word_stock/application/use_cases/sample/update_sample_use_case.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/sample_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/presentation/sample/sample_view_model.dart';

/// 仕様書 docs/detailed_design/presentation/sample/sample_page.md 4章の
/// 「ログイン中のユーザーは id が `u1` のユーザーとする」に合わせたテスト用ユーザー。
const _testUser = AppUser(id: 'u1', email: 'u1@example.com');

Sample _sample(String id, String name, DateTime createdAt) =>
    Sample(id: id, name: name, createdAt: createdAt, updatedAt: createdAt);

final _sampleA = _sample('sample-a', 'A', DateTime(2024, 1, 1));
final _sampleB = _sample('sample-b', 'B', DateTime(2024, 1, 2));
final _sampleC = _sample('sample-c', 'C', DateTime(2024, 1, 3));
// SMP-V22 用。「A」と同名だが id が異なる、作成で新しく生まれたサンプル。
final _sampleA2 = _sample('sample-a2', 'A', DateTime(2024, 1, 4));

/// GetSamplesUseCase の手書き Fake。
/// `call()` が呼ばれるたびに `results` を先頭から1つ消費して返す。
/// `gatedIndexes` に含まれる呼び出し順（0始まり）は、対応する `gates[index]` を
/// `complete()` するまで結果を返さない（並行処理の完了順を制御するテストで使う）。
class FakeGetSamplesUseCase implements GetSamplesUseCase {
  FakeGetSamplesUseCase(this.results, {Set<int> gatedIndexes = const {}}) {
    for (final i in gatedIndexes) {
      gates[i] = Completer<void>();
    }
  }

  final List<Either<Failure, List<Sample>>> results;
  final Map<int, Completer<void>> gates = {};
  int callCount = 0;
  final List<String> calledUserIds = [];

  @override
  Future<Either<Failure, List<Sample>>> call({required String userId}) async {
    final index = callCount;
    calledUserIds.add(userId);
    callCount++;
    final gate = gates[index];
    if (gate != null) {
      await gate.future;
    }
    return results[index < results.length ? index : results.length - 1];
  }
}

/// CreateSampleUseCase の手書き Fake。
class FakeCreateSampleUseCase implements CreateSampleUseCase {
  FakeCreateSampleUseCase(this.result);

  final Either<Failure, Sample> result;
  int callCount = 0;
  final List<({String userId, String name})> calls = [];

  @override
  Future<Either<Failure, Sample>> call({
    required String userId,
    required String name,
  }) async {
    calls.add((userId: userId, name: name));
    callCount++;
    return result;
  }
}

/// UpdateSampleUseCase の手書き Fake。
class FakeUpdateSampleUseCase implements UpdateSampleUseCase {
  FakeUpdateSampleUseCase(this.result);

  final Either<Failure, Sample> result;
  int callCount = 0;
  final List<({String userId, String sampleId, String name})> calls = [];

  @override
  Future<Either<Failure, Sample>> call({
    required String userId,
    required String sampleId,
    required String name,
  }) async {
    calls.add((userId: userId, sampleId: sampleId, name: name));
    callCount++;
    return result;
  }
}

/// DeleteSampleUseCase の手書き Fake。
/// `gate` を渡すと `call()` の完了を任意のタイミングまで遅延させられる
/// （削除と他の操作の完了順を制御するテストで使う）。
class FakeDeleteSampleUseCase implements DeleteSampleUseCase {
  FakeDeleteSampleUseCase(this.result, {this.gate});

  final Either<Failure, Unit> result;
  final Completer<void>? gate;
  int callCount = 0;
  final List<({String userId, String sampleId})> calls = [];

  @override
  Future<Either<Failure, Unit>> call({
    required String userId,
    required String sampleId,
  }) async {
    calls.add((userId: userId, sampleId: sampleId));
    callCount++;
    if (gate != null) {
      await gate!.future;
    }
    return result;
  }
}

ProviderContainer _makeContainer({
  required GetSamplesUseCase getSamplesUseCase,
  CreateSampleUseCase? createSampleUseCase,
  UpdateSampleUseCase? updateSampleUseCase,
  DeleteSampleUseCase? deleteSampleUseCase,
}) {
  final container = ProviderContainer(overrides: [
    getSamplesUseCaseProvider.overrideWithValue(getSamplesUseCase),
    if (createSampleUseCase != null)
      createSampleUseCaseProvider.overrideWithValue(createSampleUseCase),
    if (updateSampleUseCase != null)
      updateSampleUseCaseProvider.overrideWithValue(updateSampleUseCase),
    if (deleteSampleUseCase != null)
      deleteSampleUseCaseProvider.overrideWithValue(deleteSampleUseCase),
    currentUserProvider.overrideWithValue(_testUser),
  ]);
  addTearDown(container.dispose);
  // build() は Future.microtask で初期ロードを行うだけの同期 Notifier のため、
  // autoDispose によって初期ロード完了前に破棄されないようリスナーを張り続ける。
  container.listen(sampleViewModelProvider, (_, __) {});
  return container;
}

/// `samples` が読み込み中でなくなるまでマイクロタスクを消費して待つ。
Future<void> _waitUntilNotLoading(ProviderContainer container) async {
  while (container.read(sampleViewModelProvider).samples.isLoading) {
    await Future<void>.microtask(() {});
  }
}

/// `condition` が真になるまでマイクロタスクを消費して待つ（上限あり）。
Future<void> _waitUntil(bool Function() condition, {int maxTicks = 200}) async {
  var ticks = 0;
  while (!condition() && ticks < maxTicks) {
    await Future<void>.microtask(() {});
    ticks++;
  }
}

void main() {
  group('SampleViewModel.build', () {
    test('生成した直後、初期読み込みが完了していない場合、samples は AsyncLoading になる [SMP-V01 #7fe5c0]', () {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
      );

      expect(container.read(sampleViewModelProvider).samples.isLoading, isTrue);
    });

    test('getSamples が「A」「B」（作成日時が古い順）を返した場合、samples は AsyncData([A, B]) になり、getSamples が userId u1 で1回呼ばれる [SMP-V02 #741bef]', () async {
      final getSamplesUseCase =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final container = _makeContainer(getSamplesUseCase: getSamplesUseCase);

      await _waitUntilNotLoading(container);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(getSamplesUseCase.callCount, 1);
      expect(getSamplesUseCase.calledUserIds, ['u1']);
    });

    test('getSamples が空の一覧を返した場合、samples は AsyncData([]) になる [SMP-V03 #23dca6]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([const Right([])]),
      );

      await _waitUntilNotLoading(container);

      expect(container.read(sampleViewModelProvider).samples.value, isEmpty);
    });

    test('getSamples が UnknownFailure を返した場合、samples は AsyncError(UnknownFailure) になる [SMP-V04 #9f3345]', () async {
      final container = _makeContainer(
        getSamplesUseCase:
            FakeGetSamplesUseCase([const Left(Failure.unknown('boom'))]),
      );

      await _waitUntilNotLoading(container);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.unknown('boom'));
    });

    test('getSamples が NotFoundFailure を返した場合、samples は AsyncError(NotFoundFailure) になる [SMP-V05 #2d2b4c]', () async {
      final container = _makeContainer(
        getSamplesUseCase:
            FakeGetSamplesUseCase([const Left(Failure.notFound())]),
      );

      await _waitUntilNotLoading(container);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.notFound());
    });

    test('getSamples が NetworkFailure を返した場合、operationFailure は NetworkFailure になり、samples は AsyncData([]) になる [SMP-V06 #d6a69b]', () async {
      final container = _makeContainer(
        getSamplesUseCase:
            FakeGetSamplesUseCase([const Left(Failure.network())]),
      );

      await _waitUntilNotLoading(container);

      final state = container.read(sampleViewModelProvider);
      expect(state.operationFailure, const Failure.network());
      expect(state.samples.value, isEmpty);
    });

    test('getSamples が AuthFailure を返した場合、operationFailure は AuthFailure になり、samples は AsyncData([]) になる [SMP-V07 #b65944]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([const Left(Failure.auth())]),
      );

      await _waitUntilNotLoading(container);

      final state = container.read(sampleViewModelProvider);
      expect(state.operationFailure, const Failure.auth());
      expect(state.samples.value, isEmpty);
    });
  });

  group('SampleViewModel.refresh', () {
    test('初期読み込みが UnknownFailure で失敗した状態で、getSamples が「A」を返すようにして refresh を呼んだ場合、samples は AsyncData([A]) になり、getSamples が2回目の呼び出しでも userId u1 で呼ばれる [SMP-V08 #e2bf2c]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase([
        const Left(Failure.unknown('boom')),
        Right([_sampleA]),
      ]);
      final container = _makeContainer(getSamplesUseCase: getSamplesUseCase);
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA]);
      expect(getSamplesUseCase.calledUserIds, ['u1', 'u1']);
    });

    test('初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、読み込みが完了していない場合、samples は AsyncLoading になる [SMP-V09 #0551fd]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase(
        [const Left(Failure.unknown('boom')), Right([_sampleA])],
        gatedIndexes: {1},
      );
      final container = _makeContainer(getSamplesUseCase: getSamplesUseCase);
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      final refreshFuture = notifier.refresh();

      expect(container.read(sampleViewModelProvider).samples.isLoading, isTrue);

      getSamplesUseCase.gates[1]!.complete();
      await refreshFuture;
    });

    test('初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が再び UnknownFailure を返した場合、samples は AsyncError(UnknownFailure) になる [SMP-V10 #0e8d4b]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          const Left(Failure.unknown('boom')),
          const Left(Failure.unknown('boom')),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.unknown('boom'));
    });

    test('初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples は AsyncError(NotFoundFailure) になる [SMP-V11 #86bf63]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          const Left(Failure.unknown('boom')),
          const Left(Failure.notFound()),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.notFound());
    });

    test('初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が NetworkFailure を返した場合、operationFailure は NetworkFailure になる [SMP-V12 #d97a68]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          const Left(Failure.unknown('boom')),
          const Left(Failure.network()),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      expect(container.read(sampleViewModelProvider).operationFailure, const Failure.network());
    });

    test('初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、getSamples が AuthFailure を返した場合、operationFailure は AuthFailure になる [SMP-V13 #0ea055]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          const Left(Failure.unknown('boom')),
          const Left(Failure.auth()),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      expect(container.read(sampleViewModelProvider).operationFailure, const Failure.auth());
    });

    test('samples が AsyncData([A]) の状態で refresh を呼び、getSamples が「A」「B」を返した場合、samples は AsyncData([A, B]) になり、getSamples が userId u1 で呼ばれる [SMP-V14 #f3b21c]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase([
        Right([_sampleA]),
        Right([_sampleA, _sampleB]),
      ]);
      final container = _makeContainer(getSamplesUseCase: getSamplesUseCase);
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA, _sampleB]);
      expect(getSamplesUseCase.calledUserIds, ['u1', 'u1']);
    });

    test('samples が AsyncData([A]) の状態で refresh を呼び、getSamples が UnknownFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は UnknownFailure になる [SMP-V15 #e5b719]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          Right([_sampleA]),
          const Left(Failure.unknown('boom')),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test('samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NotFoundFailure になる [SMP-V16 #21b3a4]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          Right([_sampleA]),
          const Left(Failure.notFound()),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.notFound());
    });

    test('samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NetworkFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NetworkFailure になる [SMP-V17 #148c4b]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          Right([_sampleA]),
          const Left(Failure.network()),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.network());
    });

    test('samples が AsyncData([A]) の状態で refresh を呼び、getSamples が AuthFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は AuthFailure になる [SMP-V18 #ccb1d4]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          Right([_sampleA]),
          const Left(Failure.auth()),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.auth());
    });

    test('samples が AsyncData([]) の状態で refresh を呼び、getSamples が「A」を返した場合、samples は AsyncData([A]) になる [SMP-V19 #e1bb86]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([
          const Right([]),
          Right([_sampleA]),
        ]),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.refresh();

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA]);
    });

    test('samples が AsyncData([A]) の状態で refresh を呼び、読み込みが完了していない場合、samples は AsyncData([A]) のままである [SMP-V42 #e80659]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase(
        [Right([_sampleA]), Right([_sampleA])],
        gatedIndexes: {1},
      );
      final container = _makeContainer(getSamplesUseCase: getSamplesUseCase);
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      final refreshFuture = notifier.refresh();

      // refresh() は一覧を表示できている間は samples を AsyncLoading にしない。
      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA]);

      getSamplesUseCase.gates[1]!.complete();
      await refreshFuture;
    });
  });

  group('SampleViewModel.createSample', () {
    test('samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples は AsyncData([A, B]) になり、createSample が userId u1、name 「B」で1回呼ばれる [SMP-V20 #ac3fa6]', () async {
      final createUseCase = FakeCreateSampleUseCase(Right(_sampleB));
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
        createSampleUseCase: createUseCase,
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'B');

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA, _sampleB]);
      expect(createUseCase.calls, [(userId: 'u1', name: 'B')]);
    });

    test('samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が「B」を返した場合、samples は AsyncData([B]) になり、createSample が userId u1、name 「B」で1回呼ばれる [SMP-V21 #74719e]', () async {
      final createUseCase = FakeCreateSampleUseCase(Right(_sampleB));
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([const Right([])]),
        createSampleUseCase: createUseCase,
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'B');

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleB]);
      expect(createUseCase.calls, [(userId: 'u1', name: 'B')]);
    });

    test('samples が AsyncData([A]) の状態で createSample（name: 「A」）を呼び、createSample が「A」と別の id を持つ新しいサンプル「A」を返した場合、samples は2件で、どちらの name も「A」、id は互いに異なる [SMP-V22 #ba49ae]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
        createSampleUseCase: FakeCreateSampleUseCase(Right(_sampleA2)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'A');

      final samples = container.read(sampleViewModelProvider).samples.value!;
      expect(samples.length, 2);
      expect(samples.every((s) => s.name == 'A'), isTrue);
      expect(samples[0].id == samples[1].id, isFalse);
    });

    test('samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は UnknownFailure になる [SMP-V23 #0398ac]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
        createSampleUseCase:
            FakeCreateSampleUseCase(const Left(Failure.unknown('boom'))),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test('samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、createSample が UnknownFailure を返した場合、samples は AsyncData([]) のままで、operationFailure は UnknownFailure になる [SMP-V24 #b8ebc4]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([const Right([])]),
        createSampleUseCase:
            FakeCreateSampleUseCase(const Left(Failure.unknown('boom'))),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, isEmpty);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test('samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が NetworkFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は NetworkFailure になる [SMP-V25 #08063d]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
        createSampleUseCase:
            FakeCreateSampleUseCase(const Left(Failure.network())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.network());
    });

    test('samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、createSample が AuthFailure を返した場合、samples は AsyncData([A]) のままで、operationFailure は AuthFailure になる [SMP-V26 #37e03f]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
        createSampleUseCase: FakeCreateSampleUseCase(const Left(Failure.auth())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.auth());
    });
  });

  group('SampleViewModel.updateSample', () {
    test('samples が AsyncData([A, B, C]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が B の id を持つ「X」を返した場合、samples は AsyncData([A, X, C]) になり、updateSample が userId u1、sampleId B の id、name 「X」で1回呼ばれる [SMP-V27 #703d7d]', () async {
      final updatedB = _sampleB.copyWith(name: 'X');
      final updateUseCase = FakeUpdateSampleUseCase(Right(updatedB));
      final container = _makeContainer(
        getSamplesUseCase:
            FakeGetSamplesUseCase([Right([_sampleA, _sampleB, _sampleC])]),
        updateSampleUseCase: updateUseCase,
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      expect(
        container.read(sampleViewModelProvider).samples.value,
        [_sampleA, updatedB, _sampleC],
      );
      expect(
        updateUseCase.calls,
        [(userId: 'u1', sampleId: _sampleB.id, name: 'X')],
      );
    });

    test('samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「A」）を呼び、updateSample が B の id を持つ「A」を返した場合、samples は2件で、上から A の id の「A」、B の id の「A」になる [SMP-V28 #4211b1]', () async {
      final updatedB = _sampleB.copyWith(name: 'A');
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        updateSampleUseCase: FakeUpdateSampleUseCase(Right(updatedB)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleB.id, name: 'A');

      final samples = container.read(sampleViewModelProvider).samples.value!;
      expect(samples.length, 2);
      expect(samples[0].id, _sampleA.id);
      expect(samples[0].name, 'A');
      expect(samples[1].id, _sampleB.id);
      expect(samples[1].name, 'A');
    });

    test('samples が AsyncData([A]) の状態で updateSample（sampleId: A の id、name: 「A」）を呼び、updateSample が A の id を持つ「A」を返した場合、samples は1件で、A の id の「A」になる [SMP-V29 #4b8c44]', () async {
      final updatedA = _sampleA.copyWith(name: 'A');
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA])]),
        updateSampleUseCase: FakeUpdateSampleUseCase(Right(updatedA)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleA.id, name: 'A');

      final samples = container.read(sampleViewModelProvider).samples.value!;
      expect(samples.length, 1);
      expect(samples[0].id, _sampleA.id);
      expect(samples[0].name, 'A');
    });

    test('samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が UnknownFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は UnknownFailure になる [SMP-V30 #f37e41]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        updateSampleUseCase:
            FakeUpdateSampleUseCase(const Left(Failure.unknown('boom'))),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test('samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が NotFoundFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NotFoundFailure になる [SMP-V31 #3fdfbf]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        updateSampleUseCase:
            FakeUpdateSampleUseCase(const Left(Failure.notFound())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.notFound());
    });

    test('samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が NetworkFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NetworkFailure になる [SMP-V32 #1c4b53]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        updateSampleUseCase:
            FakeUpdateSampleUseCase(const Left(Failure.network())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.network());
    });

    test('samples が AsyncData([A, B]) の状態で updateSample（sampleId: B の id、name: 「X」）を呼び、updateSample が AuthFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は AuthFailure になる [SMP-V33 #b2d978]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        updateSampleUseCase: FakeUpdateSampleUseCase(const Left(Failure.auth())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.auth());
    });
  });

  group('SampleViewModel.deleteSample', () {
    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples は AsyncData([B]) になり、deleteSample が userId u1、sampleId A の id で1回呼ばれる [SMP-V34 #334f2e]', () async {
      final getSamplesUseCase =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB]), Right([_sampleB])]);
      final deleteUseCase = FakeDeleteSampleUseCase(const Right(unit));
      final container = _makeContainer(
        getSamplesUseCase: getSamplesUseCase,
        deleteSampleUseCase: deleteUseCase,
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);
      await _waitUntil(() => getSamplesUseCase.callCount >= 2);

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleB]);
      expect(deleteUseCase.calls, [(userId: 'u1', sampleId: _sampleA.id)]);
    });

    test('samples が AsyncData([A, B, C]) の状態で deleteSample（sampleId: B の id）を呼び、deleteSample が成功し、その後の getSamples が「A」「C」を返した場合、samples は AsyncData([A, C]) になる [SMP-V35 #7baf62]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase([
        Right([_sampleA, _sampleB, _sampleC]),
        Right([_sampleA, _sampleC]),
      ]);
      final container = _makeContainer(
        getSamplesUseCase: getSamplesUseCase,
        deleteSampleUseCase: FakeDeleteSampleUseCase(const Right(unit)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleB.id);
      await _waitUntil(() => getSamplesUseCase.callCount >= 2);

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA, _sampleC]);
    });

    test('samples が AsyncData([A]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が空の一覧を返した場合、samples は AsyncData([]) になる [SMP-V36 #e9b1d5]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase([
        Right([_sampleA]),
        const Right([]),
      ]);
      final container = _makeContainer(
        getSamplesUseCase: getSamplesUseCase,
        deleteSampleUseCase: FakeDeleteSampleUseCase(const Right(unit)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);
      await _waitUntil(() => getSamplesUseCase.callCount >= 2);

      expect(container.read(sampleViewModelProvider).samples.value, isEmpty);
    });

    test('samples が AsyncData([A, B]) で、Repository 上では A が既に削除されている状態で deleteSample（sampleId: A の id）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、samples は AsyncData([B]) になり、operationFailure は null になる [SMP-V37 #012201]', () async {
      final getSamplesUseCase =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB]), Right([_sampleB])]);
      final container = _makeContainer(
        getSamplesUseCase: getSamplesUseCase,
        // 削除対象が既に存在しない場合も、リポジトリ契約（SMP-R12）どおり成功として扱われる。
        deleteSampleUseCase: FakeDeleteSampleUseCase(const Right(unit)),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);
      await _waitUntil(() => getSamplesUseCase.callCount >= 2);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleB]);
      expect(state.operationFailure, isNull);
    });

    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が UnknownFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は UnknownFailure になる [SMP-V38 #b32133]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        deleteSampleUseCase:
            FakeDeleteSampleUseCase(const Left(Failure.unknown('boom'))),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が NotFoundFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NotFoundFailure になる [SMP-V39 #da4019]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        deleteSampleUseCase:
            FakeDeleteSampleUseCase(const Left(Failure.notFound())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.notFound());
    });

    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が NetworkFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は NetworkFailure になる [SMP-V40 #75c7ef]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        deleteSampleUseCase:
            FakeDeleteSampleUseCase(const Left(Failure.network())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.network());
    });

    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、deleteSample が AuthFailure を返した場合、samples は AsyncData([A, B]) のままで、operationFailure は AuthFailure になる [SMP-V41 #a205ef]', () async {
      final container = _makeContainer(
        getSamplesUseCase: FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]),
        deleteSampleUseCase: FakeDeleteSampleUseCase(const Left(Failure.auth())),
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.auth());
    });

    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、その完了前に createSample（name: 「C」）を呼んで、createSample が「C」を返し、deleteSample が成功し、削除後の getSamples が「B」「C」を返した場合、両方の完了後 samples は AsyncData([B, C]) になる [SMP-V43 #ab4762]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase([
        Right([_sampleA, _sampleB]),
        Right([_sampleB, _sampleC]),
      ]);
      final deleteGate = Completer<void>();
      final deleteUseCase =
          FakeDeleteSampleUseCase(const Right(unit), gate: deleteGate);
      final createUseCase = FakeCreateSampleUseCase(Right(_sampleC));
      final container = _makeContainer(
        getSamplesUseCase: getSamplesUseCase,
        createSampleUseCase: createUseCase,
        deleteSampleUseCase: deleteUseCase,
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      final deleteFuture = notifier.deleteSample(sampleId: _sampleA.id);
      // deleteSample はまだ deleteGate 待ちで完了していない。先に createSample を完了させる
      // （SMP-V43 の条件「その完了前に createSample を呼んで、createSample が先に完了する」を作るための順序制御）。
      await notifier.createSample(name: 'C');

      deleteGate.complete();
      await deleteFuture;
      await _waitUntil(() => getSamplesUseCase.callCount >= 2);

      expect(
        container.read(sampleViewModelProvider).samples.value,
        [_sampleB, _sampleC],
      );
    });

    test('samples が AsyncData([A, B]) の状態で deleteSample（sampleId: A の id）を呼び、その完了前に refresh を呼んで、refresh の getSamples が「A」「B」を、削除後の getSamples が「B」を返し、refresh の方が後に完了した場合、両方の完了後 samples は AsyncData([B]) になる [SMP-V44 #3c8a70]', () async {
      final getSamplesUseCase = FakeGetSamplesUseCase(
        [
          Right([_sampleA, _sampleB]), // build
          Right([_sampleA, _sampleB]), // 手動 refresh（後に完了するが古いので無視される）
          Right([_sampleB]), // 削除起因の refresh（先に完了する）
        ],
        gatedIndexes: {1, 2},
      );
      final deleteUseCase = FakeDeleteSampleUseCase(const Right(unit));
      final container = _makeContainer(
        getSamplesUseCase: getSamplesUseCase,
        deleteSampleUseCase: deleteUseCase,
      );
      await _waitUntilNotLoading(container);

      final notifier = container.read(sampleViewModelProvider.notifier);
      final deleteFuture = notifier.deleteSample(sampleId: _sampleA.id);
      final refreshFuture = notifier.refresh();

      // delete が完了し、削除起因の refresh が getSamples を呼ぶまで待つ（呼び出し順で2件目）。
      await _waitUntil(() => getSamplesUseCase.callCount >= 3);

      // 削除起因の refresh（3件目の呼び出し）を先に完了させる
      // （SMP-V44 の条件「refresh の方が後に完了した」を作るための順序制御。中間状態は検証しない）。
      getSamplesUseCase.gates[2]!.complete();
      await _waitUntil(
        () => container.read(sampleViewModelProvider).samples.value?.length == 1,
      );

      // 手動 refresh（2件目の呼び出し）を後から完了させる。revision が古いため無視される。
      getSamplesUseCase.gates[1]!.complete();
      await refreshFuture;
      await deleteFuture;
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleB]);
    });
  });
}
