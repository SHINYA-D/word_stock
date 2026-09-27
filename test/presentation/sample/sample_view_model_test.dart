import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
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

/// 仕様書（docs/detailed_design/presentation/sample/sample_page.md）4章の
/// 「条件のログイン中のユーザーは id が u1 のユーザーとする」に合わせたテスト用ユーザー。
const _testUser = AppUser(id: 'u1', email: 'u1@example.com');

final _sampleA = Sample(
  id: 'sample-a',
  name: 'A',
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);
final _sampleB = Sample(
  id: 'sample-b',
  name: 'B',
  createdAt: DateTime(2024, 1, 2),
  updatedAt: DateTime(2024, 1, 2),
);
final _sampleC = Sample(
  id: 'sample-c',
  name: 'C',
  createdAt: DateTime(2024, 1, 3),
  updatedAt: DateTime(2024, 1, 3),
);

/// GetSamplesUseCase の手書き Fake。
/// 呼び出しごとに Completer を1つ積む。コンストラクタに渡した `autoResults` の件数分は
/// 呼ばれた瞬間に自動で解決する。それを超える呼び出しは `pending` から手動で解決する
/// （SMP-V43・SMP-V44 のような、呼び出し順と完了順が食い違うケースを再現するため）。
class FakeGetSamplesUseCase implements GetSamplesUseCase {
  FakeGetSamplesUseCase([this._autoResults = const []]);

  final List<Either<Failure, List<Sample>>> _autoResults;
  final List<String> calledUserIds = [];
  final List<Completer<Either<Failure, List<Sample>>>> pending = [];

  @override
  Future<Either<Failure, List<Sample>>> call({required String userId}) {
    calledUserIds.add(userId);
    final index = pending.length;
    final completer = Completer<Either<Failure, List<Sample>>>();
    pending.add(completer);
    if (index < _autoResults.length) {
      completer.complete(_autoResults[index]);
    }
    return completer.future;
  }
}

/// CreateSampleUseCase の手書き Fake。1テスト内では1回だけ呼ばれる前提。
class FakeCreateSampleUseCase implements CreateSampleUseCase {
  FakeCreateSampleUseCase([Either<Failure, Sample>? autoResult]) {
    if (autoResult != null) completer.complete(autoResult);
  }

  final Completer<Either<Failure, Sample>> completer = Completer();
  String? calledUserId;
  String? calledName;
  int callCount = 0;

  @override
  Future<Either<Failure, Sample>> call({
    required String userId,
    required String name,
  }) {
    callCount++;
    calledUserId = userId;
    calledName = name;
    return completer.future;
  }
}

/// UpdateSampleUseCase の手書き Fake。1テスト内では1回だけ呼ばれる前提。
class FakeUpdateSampleUseCase implements UpdateSampleUseCase {
  FakeUpdateSampleUseCase([Either<Failure, Sample>? autoResult]) {
    if (autoResult != null) completer.complete(autoResult);
  }

  final Completer<Either<Failure, Sample>> completer = Completer();
  String? calledUserId;
  String? calledSampleId;
  String? calledName;
  int callCount = 0;

  @override
  Future<Either<Failure, Sample>> call({
    required String userId,
    required String sampleId,
    required String name,
  }) {
    callCount++;
    calledUserId = userId;
    calledSampleId = sampleId;
    calledName = name;
    return completer.future;
  }
}

/// DeleteSampleUseCase の手書き Fake。1テスト内では1回だけ呼ばれる前提。
class FakeDeleteSampleUseCase implements DeleteSampleUseCase {
  FakeDeleteSampleUseCase([Either<Failure, Unit>? autoResult]) {
    if (autoResult != null) completer.complete(autoResult);
  }

  final Completer<Either<Failure, Unit>> completer = Completer();
  String? calledUserId;
  String? calledSampleId;
  int callCount = 0;

  @override
  Future<Either<Failure, Unit>> call({
    required String userId,
    required String sampleId,
  }) {
    callCount++;
    calledUserId = userId;
    calledSampleId = sampleId;
    return completer.future;
  }
}

ProviderContainer _makeContainer({
  required FakeGetSamplesUseCase getSamplesUseCase,
  FakeCreateSampleUseCase? createSampleUseCase,
  FakeUpdateSampleUseCase? updateSampleUseCase,
  FakeDeleteSampleUseCase? deleteSampleUseCase,
}) {
  final container = ProviderContainer(overrides: [
    getSamplesUseCaseProvider.overrideWithValue(getSamplesUseCase),
    createSampleUseCaseProvider
        .overrideWithValue(createSampleUseCase ?? FakeCreateSampleUseCase()),
    updateSampleUseCaseProvider
        .overrideWithValue(updateSampleUseCase ?? FakeUpdateSampleUseCase()),
    deleteSampleUseCaseProvider
        .overrideWithValue(deleteSampleUseCase ?? FakeDeleteSampleUseCase()),
    currentUserProvider.overrideWithValue(_testUser),
  ]);
  addTearDown(container.dispose);
  // build() を即座に走らせ、以後もリスナーを保持する。
  // sampleViewModelProvider は AutoDispose のため、リスナーが無いまま read するだけだと
  // build() 内の Future.microtask(() => _initState()) が走る前に provider が破棄され、
  // 新しい notifier インスタンスが作られて _userId が未初期化のままになる。
  container.listen(sampleViewModelProvider, (_, __) {}, fireImmediately: true);
  return container;
}

/// build() 内の `Future.microtask(() => _initState())` が完了するまでイベントループを流す。
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('SampleViewModel.build', () {
    test(
        'ViewModelを生成し、初期読み込みが完了していない場合、samples が AsyncLoading になる '
        '[SMP-V01 #7fe5c0]', () {
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      final state = container.read(sampleViewModelProvider);

      expect(state.samples.isLoading, isTrue);
      expect(state.samples.hasValue, isFalse);
    });

    test(
        'ViewModelを生成し、getSamples が「A」「B」（作成日時が古い順）を返した場合、'
        'samples が AsyncData([A, B]) になり、Repository の getSamples が userId u1 で1回呼ばれる '
        '[SMP-V02 #741bef]', () async {
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(getSamples.calledUserIds, ['u1']);
    });

    test(
        'ViewModelを生成し、getSamples が空の一覧を返した場合、samples が AsyncData([]) になる '
        '[SMP-V03 #23dca6]', () async {
      final getSamples = FakeGetSamplesUseCase([const Right([])]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      await _flush();

      expect(container.read(sampleViewModelProvider).samples.value, isEmpty);
    });

    test(
        'ViewModelを生成し、getSamples が UnknownFailure を返した場合、'
        'samples が AsyncError(UnknownFailure) になる '
        '[SMP-V04 #9f3345]', () async {
      final getSamples =
          FakeGetSamplesUseCase([Left(Failure.unknown('boom'))]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.unknown('boom'));
    });

    test(
        'ViewModelを生成し、getSamples が NotFoundFailure を返した場合、'
        'samples が AsyncError(NotFoundFailure) になる '
        '[SMP-V05 #2d2b4c]', () async {
      final getSamples =
          FakeGetSamplesUseCase([const Left(Failure.notFound())]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.notFound());
    });

    test(
        'ViewModelを生成し、getSamples が NetworkFailure を返した場合、'
        'operationFailure が NetworkFailure になり、samples が AsyncData([]) になる '
        '[SMP-V06 #d6a69b]', () async {
      final getSamples =
          FakeGetSamplesUseCase([const Left(Failure.network())]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.operationFailure, const Failure.network());
      expect(state.samples.value, isEmpty);
    });

    test(
        'ViewModelを生成し、getSamples が AuthFailure を返した場合、'
        'operationFailure が AuthFailure になり、samples が AsyncData([]) になる '
        '[SMP-V07 #b65944]', () async {
      final getSamples = FakeGetSamplesUseCase([const Left(Failure.auth())]);
      final container = _makeContainer(getSamplesUseCase: getSamples);

      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.operationFailure, const Failure.auth());
      expect(state.samples.value, isEmpty);
    });
  });

  group('SampleViewModel.refresh', () {
    test(
        '初期読み込みが UnknownFailure で失敗した状態で、getSamples が「A」を返すようにして refresh を呼んだ場合、'
        'samples が AsyncData([A]) になり、Repository の getSamples が2回目の呼び出しでも userId u1 で呼ばれる '
        '[SMP-V08 #e2bf2c]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Left(Failure.unknown('boom')), Right([_sampleA])],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(getSamples.calledUserIds, ['u1', 'u1']);
    });

    test(
        '初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、読み込みが完了していない場合、'
        'samples が AsyncLoading になる '
        '[SMP-V09 #0551fd]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Left(Failure.unknown('boom')), Right([_sampleA])],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      final future = notifier.refresh();

      expect(container.read(sampleViewModelProvider).samples.isLoading, isTrue);

      await future;
    });

    test(
        '初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、'
        'getSamples が再び UnknownFailure を返した場合、samples が AsyncError(UnknownFailure) になる '
        '[SMP-V10 #0e8d4b]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Left(Failure.unknown('boom')), Left(Failure.unknown('boom2'))],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.unknown('boom2'));
    });

    test(
        '初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、'
        'getSamples が NotFoundFailure を返した場合、samples が AsyncError(NotFoundFailure) になる '
        '[SMP-V11 #86bf63]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Left(Failure.unknown('boom')), const Left(Failure.notFound())],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, const Failure.notFound());
    });

    test(
        '初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、'
        'getSamples が NetworkFailure を返した場合、operationFailure が NetworkFailure になる '
        '[SMP-V12 #d97a68]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Left(Failure.unknown('boom')), const Left(Failure.network())],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      expect(
        container.read(sampleViewModelProvider).operationFailure,
        const Failure.network(),
      );
    });

    test(
        '初期読み込みが UnknownFailure で失敗した状態で refresh を呼び、'
        'getSamples が AuthFailure を返した場合、operationFailure が AuthFailure になる '
        '[SMP-V13 #0ea055]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Left(Failure.unknown('boom')), const Left(Failure.auth())],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      expect(
        container.read(sampleViewModelProvider).operationFailure,
        const Failure.auth(),
      );
    });

    test(
        'samples が AsyncData([A]) の状態で refresh を呼び、getSamples が「A」「B」を返した場合、'
        'samples が AsyncData([A, B]) になり、Repository の getSamples が userId u1 で呼ばれる '
        '[SMP-V14 #f3b21c]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Right([_sampleA]), Right([_sampleA, _sampleB])],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(getSamples.calledUserIds, ['u1', 'u1']);
    });

    test(
        'samples が AsyncData([A]) の状態で refresh を呼び、getSamples が UnknownFailure を返した場合、'
        'samples が AsyncData([A]) のままになり、operationFailure が UnknownFailure になる '
        '[SMP-V15 #e5b719]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Right([_sampleA]), Left(Failure.unknown('boom'))],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test(
        'samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NotFoundFailure を返した場合、'
        'samples が AsyncData([A]) のままになり、operationFailure が NotFoundFailure になる '
        '[SMP-V16 #21b3a4]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Right([_sampleA]), const Left(Failure.notFound())],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.notFound());
    });

    test(
        'samples が AsyncData([A]) の状態で refresh を呼び、getSamples が NetworkFailure を返した場合、'
        'samples が AsyncData([A]) のままになり、operationFailure が NetworkFailure になる '
        '[SMP-V17 #148c4b]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Right([_sampleA]), const Left(Failure.network())],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.network());
    });

    test(
        'samples が AsyncData([A]) の状態で refresh を呼び、getSamples が AuthFailure を返した場合、'
        'samples が AsyncData([A]) のままになり、operationFailure が AuthFailure になる '
        '[SMP-V18 #ccb1d4]', () async {
      final getSamples = FakeGetSamplesUseCase(
        [Right([_sampleA]), const Left(Failure.auth())],
      );
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.auth());
    });

    test(
        'samples が AsyncData([]) の状態で refresh を呼び、getSamples が「A」を返した場合、'
        'samples が AsyncData([A]) になる '
        '[SMP-V19 #e1bb86]', () async {
      final getSamples =
          FakeGetSamplesUseCase([const Right([]), Right([_sampleA])]);
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.refresh();

      expect(container.read(sampleViewModelProvider).samples.value, [_sampleA]);
    });

    test(
        'samples が AsyncData([A]) の状態で refresh を呼び、読み込みが完了していない場合、'
        'samples が AsyncData([A]) のままになる '
        '[SMP-V42 #e80659]', () async {
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA]), Right([_sampleA])]);
      final container = _makeContainer(getSamplesUseCase: getSamples);
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      final future = notifier.refresh();

      expect(
        container.read(sampleViewModelProvider).samples.value,
        [_sampleA],
      );

      await future;
    });
  });

  group('SampleViewModel.createSample', () {
    test(
        'samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、'
        'createSample が「B」を返した場合、samples が AsyncData([A, B]) になり、'
        'Repository の createSample が userId u1、name 「B」で1回呼ばれる '
        '[SMP-V20 #ac3fa6]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA])]);
      final create = FakeCreateSampleUseCase(Right(_sampleB));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(create.calledUserId, 'u1');
      expect(create.calledName, 'B');
      expect(create.callCount, 1);
    });

    test(
        'samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、'
        'createSample が「B」を返した場合、samples が AsyncData([B]) になり、'
        'Repository の createSample が userId u1、name 「B」で1回呼ばれる '
        '[SMP-V21 #74719e]', () async {
      final getSamples = FakeGetSamplesUseCase([const Right([])]);
      final create = FakeCreateSampleUseCase(Right(_sampleB));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleB]);
      expect(create.calledUserId, 'u1');
      expect(create.calledName, 'B');
      expect(create.callCount, 1);
    });

    test(
        'samples が AsyncData([A]) の状態で createSample（name: 「A」）を呼び、'
        'createSample が「A」と別の id を持つ新しいサンプル「A」を返した場合、'
        'samples は2件で、どちらの name も「A」、id は互いに異なる '
        '[SMP-V22 #ba49ae]', () async {
      final newA = Sample(
        id: 'sample-a2',
        name: 'A',
        createdAt: DateTime(2024, 1, 4),
        updatedAt: DateTime(2024, 1, 4),
      );
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA])]);
      final create = FakeCreateSampleUseCase(Right(newA));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'A');

      final samples = container.read(sampleViewModelProvider).samples.value!;
      expect(samples.length, 2);
      expect(samples.every((s) => s.name == 'A'), isTrue);
      expect(samples[0].id, isNot(samples[1].id));
    });

    test(
        'samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、'
        'createSample が UnknownFailure を返した場合、samples が AsyncData([A]) のままになり、'
        'operationFailure が UnknownFailure になる '
        '[SMP-V23 #0398ac]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA])]);
      final create = FakeCreateSampleUseCase(Left(Failure.unknown('boom')));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test(
        'samples が AsyncData([]) の状態で createSample（name: 「B」）を呼び、'
        'createSample が UnknownFailure を返した場合、samples が AsyncData([]) のままになり、'
        'operationFailure が UnknownFailure になる '
        '[SMP-V24 #b8ebc4]', () async {
      final getSamples = FakeGetSamplesUseCase([const Right([])]);
      final create = FakeCreateSampleUseCase(Left(Failure.unknown('boom')));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, isEmpty);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test(
        'samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、'
        'createSample が NetworkFailure を返した場合、samples が AsyncData([A]) のままになり、'
        'operationFailure が NetworkFailure になる '
        '[SMP-V25 #08063d]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA])]);
      final create = FakeCreateSampleUseCase(const Left(Failure.network()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.network());
    });

    test(
        'samples が AsyncData([A]) の状態で createSample（name: 「B」）を呼び、'
        'createSample が AuthFailure を返した場合、samples が AsyncData([A]) のままになり、'
        'operationFailure が AuthFailure になる '
        '[SMP-V26 #37e03f]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA])]);
      final create = FakeCreateSampleUseCase(const Left(Failure.auth()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.createSample(name: 'B');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA]);
      expect(state.operationFailure, const Failure.auth());
    });
  });

  group('SampleViewModel.updateSample', () {
    test(
        'samples が AsyncData([A, B, C]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、'
        'updateSample が Bのid を持つ「X」を返した場合、samples が AsyncData([A, X, C]) になり、'
        'Repository の updateSample が userId u1、sampleId Bのid、name 「X」で1回呼ばれる '
        '[SMP-V27 #703d7d]', () async {
      final updatedX = Sample(
        id: _sampleB.id,
        name: 'X',
        createdAt: _sampleB.createdAt,
        updatedAt: DateTime(2024, 1, 5),
      );
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB, _sampleC])]);
      final update = FakeUpdateSampleUseCase(Right(updatedX));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, updatedX, _sampleC]);
      expect(update.calledUserId, 'u1');
      expect(update.calledSampleId, _sampleB.id);
      expect(update.calledName, 'X');
      expect(update.callCount, 1);
    });

    test(
        'samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「A」）を呼び、'
        'updateSample が Bのid を持つ「A」を返した場合、samples は2件で、'
        '上から Aのidの「A」、Bのidの「A」になる '
        '[SMP-V28 #4211b1]', () async {
      final updatedA = Sample(
        id: _sampleB.id,
        name: 'A',
        createdAt: _sampleB.createdAt,
        updatedAt: DateTime(2024, 1, 5),
      );
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final update = FakeUpdateSampleUseCase(Right(updatedA));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleB.id, name: 'A');

      final samples = container.read(sampleViewModelProvider).samples.value!;
      expect(samples.length, 2);
      expect(samples[0].id, _sampleA.id);
      expect(samples[0].name, 'A');
      expect(samples[1].id, _sampleB.id);
      expect(samples[1].name, 'A');
    });

    test(
        'samples が AsyncData([A]) の状態で updateSample（sampleId: Aのid、name: 「A」）を呼び、'
        'updateSample が Aのid を持つ「A」を返した場合、samples は1件で Aのidの「A」になる '
        '[SMP-V29 #4b8c44]', () async {
      final updatedA = Sample(
        id: _sampleA.id,
        name: 'A',
        createdAt: _sampleA.createdAt,
        updatedAt: DateTime(2024, 1, 5),
      );
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA])]);
      final update = FakeUpdateSampleUseCase(Right(updatedA));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleA.id, name: 'A');

      final samples = container.read(sampleViewModelProvider).samples.value!;
      expect(samples.length, 1);
      expect(samples.single.id, _sampleA.id);
      expect(samples.single.name, 'A');
    });

    test(
        'samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、'
        'updateSample が UnknownFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が UnknownFailure になる '
        '[SMP-V30 #f37e41]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final update = FakeUpdateSampleUseCase(Left(Failure.unknown('boom')));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test(
        'samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、'
        'updateSample が NotFoundFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が NotFoundFailure になる '
        '[SMP-V31 #3fdfbf]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final update = FakeUpdateSampleUseCase(const Left(Failure.notFound()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.notFound());
    });

    test(
        'samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、'
        'updateSample が NetworkFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が NetworkFailure になる '
        '[SMP-V32 #1c4b53]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final update = FakeUpdateSampleUseCase(const Left(Failure.network()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.network());
    });

    test(
        'samples が AsyncData([A, B]) の状態で updateSample（sampleId: Bのid、name: 「X」）を呼び、'
        'updateSample が AuthFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が AuthFailure になる '
        '[SMP-V33 #b2d978]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final update = FakeUpdateSampleUseCase(const Left(Failure.auth()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        updateSampleUseCase: update,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.updateSample(sampleId: _sampleB.id, name: 'X');

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.auth());
    });
  });

  group('SampleViewModel.deleteSample', () {
    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'deleteSample が成功し、その後の getSamples が「B」を返した場合、samples が AsyncData([B]) になり、'
        'Repository の deleteSample が userId u1、sampleId Aのidで1回呼ばれる '
        '[SMP-V34 #334f2e]', () async {
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB]), Right([_sampleB])]);
      final delete = FakeDeleteSampleUseCase(const Right(unit));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);
      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleB]);
      expect(delete.calledUserId, 'u1');
      expect(delete.calledSampleId, _sampleA.id);
      expect(delete.callCount, 1);
    });

    test(
        'samples が AsyncData([A, B, C]) の状態で deleteSample（sampleId: Bのid）を呼び、'
        'deleteSample が成功し、その後の getSamples が「A」「C」を返した場合、samples が AsyncData([A, C]) になる '
        '[SMP-V35 #7baf62]', () async {
      final getSamples = FakeGetSamplesUseCase([
        Right([_sampleA, _sampleB, _sampleC]),
        Right([_sampleA, _sampleC]),
      ]);
      final delete = FakeDeleteSampleUseCase(const Right(unit));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleB.id);
      await _flush();

      expect(
        container.read(sampleViewModelProvider).samples.value,
        [_sampleA, _sampleC],
      );
    });

    test(
        'samples が AsyncData([A]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'deleteSample が成功し、その後の getSamples が空の一覧を返した場合、samples が AsyncData([]) になる '
        '[SMP-V36 #e9b1d5]', () async {
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA]), const Right([])]);
      final delete = FakeDeleteSampleUseCase(const Right(unit));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);
      await _flush();

      expect(container.read(sampleViewModelProvider).samples.value, isEmpty);
    });

    test(
        'samples が AsyncData([A, B])（Repository上ではAが既に削除されている）の状態で '
        'deleteSample（sampleId: Aのid）を呼び、deleteSample が成功し、その後の getSamples が「B」を返した場合、'
        'samples が AsyncData([B]) になり、operationFailure が null になる '
        '[SMP-V37 #012201]', () async {
      final getSamples =
          FakeGetSamplesUseCase([Right([_sampleA, _sampleB]), Right([_sampleB])]);
      final delete = FakeDeleteSampleUseCase(const Right(unit));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);
      await _flush();

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleB]);
      expect(state.operationFailure, isNull);
    });

    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'deleteSample が UnknownFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が UnknownFailure になる '
        '[SMP-V38 #b32133]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final delete = FakeDeleteSampleUseCase(Left(Failure.unknown('boom')));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.unknown('boom'));
    });

    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'deleteSample が NotFoundFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が NotFoundFailure になる '
        '[SMP-V39 #da4019]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final delete = FakeDeleteSampleUseCase(const Left(Failure.notFound()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.notFound());
    });

    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'deleteSample が NetworkFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が NetworkFailure になる '
        '[SMP-V40 #75c7ef]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final delete = FakeDeleteSampleUseCase(const Left(Failure.network()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.network());
    });

    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'deleteSample が AuthFailure を返した場合、samples が AsyncData([A, B]) のままになり、'
        'operationFailure が AuthFailure になる '
        '[SMP-V41 #a205ef]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final delete = FakeDeleteSampleUseCase(const Left(Failure.auth()));
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      await notifier.deleteSample(sampleId: _sampleA.id);

      final state = container.read(sampleViewModelProvider);
      expect(state.samples.value, [_sampleA, _sampleB]);
      expect(state.operationFailure, const Failure.auth());
    });
  });

  group('SampleViewModel 同時実行（revisionガードによる古い読み取りの破棄）', () {
    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'その完了前に createSample（name: 「C」）を呼んで、createSample が「C」を返し、'
        'deleteSample が成功し、削除後の getSamples が「B」「C」を返した場合、'
        '両方の完了後、samples が AsyncData([B, C]) になる '
        '[SMP-V43 #ab4762]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final create = FakeCreateSampleUseCase(); // 手動で解決する
      final delete = FakeDeleteSampleUseCase(); // 手動で解決する
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        createSampleUseCase: create,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      final deleteFuture = notifier.deleteSample(sampleId: _sampleA.id);
      final createFuture = notifier.createSample(name: 'C');

      // createSample を先に完了させる
      create.completer.complete(Right(_sampleC));
      await createFuture;

      // 続けて deleteSample を完了させる（内部で refresh が走り、getSamples の2回目の呼び出しが登録される）
      delete.completer.complete(const Right(unit));
      await deleteFuture;

      // 削除後の getSamples（2回目の呼び出し）に「B」「C」を解決する
      getSamples.pending[1].complete(Right([_sampleB, _sampleC]));
      await _flush();

      expect(
        container.read(sampleViewModelProvider).samples.value,
        [_sampleB, _sampleC],
      );
    });

    test(
        'samples が AsyncData([A, B]) の状態で deleteSample（sampleId: Aのid）を呼び、'
        'その完了前に refresh を呼んで、refresh の getSamples が「A」「B」を、'
        '削除後の getSamples が「B」を返し、refresh の方が後に完了した場合、'
        '両方の完了後、samples が AsyncData([B]) になる '
        '[SMP-V44 #3c8a70]', () async {
      final getSamples = FakeGetSamplesUseCase([Right([_sampleA, _sampleB])]);
      final delete = FakeDeleteSampleUseCase(); // 手動で解決する
      final container = _makeContainer(
        getSamplesUseCase: getSamples,
        deleteSampleUseCase: delete,
      );
      await _flush();
      final notifier = container.read(sampleViewModelProvider.notifier);

      final deleteFuture = notifier.deleteSample(sampleId: _sampleA.id);
      // 明示的な refresh（getSamples の2回目の呼び出し = pending[1]）
      final refreshFuture = notifier.refresh();

      // 削除を先に完了させる（内部の refresh で getSamples の3回目の呼び出し = pending[2] が登録される）
      delete.completer.complete(const Right(unit));
      await deleteFuture;

      // 削除後の getSamples（3回目の呼び出し）が先に完了する
      getSamples.pending[2].complete(Right([_sampleB]));
      await _flush();

      // 明示的な refresh の getSamples（2回目の呼び出し）が後から完了する（古い読み取りとして捨てられる）
      getSamples.pending[1].complete(Right([_sampleA, _sampleB]));
      await _flush();
      await refreshFuture;

      expect(
        container.read(sampleViewModelProvider).samples.value,
        [_sampleB],
      );
    });
  });
}
