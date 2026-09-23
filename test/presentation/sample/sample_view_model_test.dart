import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/presentation/sample/sample_state.dart';
import 'package:word_stock/presentation/sample/sample_view_model.dart';

import '../../helpers/fake_infrastructure.dart';

/// 仕様書（docs/detailed_design/presentation/sample/sample_page.md）4章
/// 「ログイン中のユーザーの id は u1 とする」に合わせたテスト用ユーザー。
/// 期待値はすべて同仕様書 4章「状態管理仕様（SampleViewModel）」の
/// SMP-V01〜SMP-V44（44件すべて）から作成している。
const _testUser = AppUser(id: 'u1', email: 'u1@example.com');

Sample _sample(
  String id,
  String name, {
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime(2024, 1, 1);
  return Sample(
    id: id,
    name: name,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

ProviderContainer _makeContainer(FakeSampleRepository repository) {
  final container = ProviderContainer(
    overrides: [
      sampleRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWithValue(_testUser),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// build() の初期ロードは `Future.microtask` で発火する fire-and-forget のため、
/// 完了を待つには state の変化を監視する必要がある。
Future<void> _waitUntil(
  ProviderContainer container,
  bool Function(SampleState) predicate,
) async {
  if (predicate(container.read(sampleViewModelProvider))) return;
  final completer = Completer<void>();
  late final ProviderSubscription<SampleState> sub;
  sub = container.listen(sampleViewModelProvider, (prev, next) {
    if (predicate(next) && !completer.isCompleted) {
      completer.complete();
    }
  });
  await completer.future;
  sub.close();
}

Future<void> _waitForInitialLoad(ProviderContainer container) =>
    _waitUntil(container, (s) => !s.samples.isLoading);

void main() {
  group('SampleViewModel.build()', () {
    test('ViewModelを生成した直後（取得が完了する前）の場合、samplesがAsyncLoadingになる [SMP-V01]', () {
      final repo = FakeSampleRepository();
      final container = _makeContainer(repo);

      final state = container.read(sampleViewModelProvider);

      expect(state.samples.isLoading, isTrue);
    });

    test(
      'A・Bの2件がある状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で1回呼ばれる [SMP-V02]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);

        await _waitForInitialLoad(container);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.hasValue, isTrue);
        expect(
          state.samples.value!.map((e) => e.name).toList(),
          ['A', 'B'],
        );
        expect(repo.getCalls.length, 1);
        expect(repo.getCalls.single.userId, 'u1');
      },
    );

    test('サンプルが0件の状態でViewModelを生成し取得が完了した場合、samplesがAsyncData([])になる [SMP-V03]', () async {
      final repo = FakeSampleRepository();
      final container = _makeContainer(repo);

      await _waitForInitialLoad(container);
      final state = container.read(sampleViewModelProvider);

      expect(state.samples.hasValue, isTrue);
      expect(state.samples.value, isEmpty);
    });

    test('ViewModelを生成し取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V04]', () async {
      const failure = Failure.unknown('boom');
      final repo = FakeSampleRepository()..getFailures.add(failure);
      final container = _makeContainer(repo);

      await _waitForInitialLoad(container);
      final state = container.read(sampleViewModelProvider);

      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, failure);
    });

    test('ViewModelを生成し取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V05]', () async {
      const failure = Failure.notFound();
      final repo = FakeSampleRepository()..getFailures.add(failure);
      final container = _makeContainer(repo);

      await _waitForInitialLoad(container);
      final state = container.read(sampleViewModelProvider);

      expect(state.samples.hasError, isTrue);
      expect(state.samples.error, failure);
    });

    test('ViewModelを生成し取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V06]', () async {
      const failure = Failure.network();
      final repo = FakeSampleRepository()..getFailures.add(failure);
      final container = _makeContainer(repo);

      await _waitForInitialLoad(container);
      final state = container.read(sampleViewModelProvider);

      expect(state.operationFailure, failure);
    });

    test('ViewModelを生成し取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V07]', () async {
      const failure = Failure.auth();
      final repo = FakeSampleRepository()..getFailures.add(failure);
      final container = _makeContainer(repo);

      await _waitForInitialLoad(container);
      final state = container.read(sampleViewModelProvider);

      expect(state.operationFailure, failure);
    });
  });

  group('SampleViewModel.refresh()', () {
    test(
      'samplesがAsyncError(UnknownFailure)の状態で、Aの1件が取得できるようにしてからrefreshを呼んだ場合、samplesがAsyncData([A])になりgetSamplesが2回目の呼び出しでもuserId「u1」で呼ばれる [SMP-V08]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository()
          ..getFailures.add(const Failure.unknown('boom'));
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);
        expect(container.read(sampleViewModelProvider).samples.hasError, isTrue);

        repo.samples = [a];
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.hasValue, isTrue);
        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(repo.getCalls.length, 2);
        expect(repo.getCalls.last.userId, 'u1');
      },
    );

    test(
      '初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び、読み込みが完了していない場合、samplesがAsyncLoadingになる [SMP-V09]',
      () async {
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository()..getFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final gate = Completer<void>();
        repo.getGate = gate;
        final notifier = container.read(sampleViewModelProvider.notifier);
        final refreshFuture = notifier.refresh();
        // gate を解放するまでは読み込みが完了していない状態を観測する
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.isLoading, isTrue);

        gate.complete();
        await refreshFuture;
      },
    );

    test(
      '初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得が再びUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V10]',
      () async {
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository()..getFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.hasError, isTrue);
        expect(state.samples.error, failure);
      },
    );

    test(
      '初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がNotFoundFailureで失敗した場合、samplesがAsyncError(NotFoundFailure)になる [SMP-V11]',
      () async {
        final repo = FakeSampleRepository()
          ..getFailures.add(const Failure.unknown('boom'));
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        const failure = Failure.notFound();
        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.hasError, isTrue);
        expect(state.samples.error, failure);
      },
    );

    test(
      '初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がNetworkFailureで失敗した場合、operationFailureがNetworkFailureになる [SMP-V12]',
      () async {
        final repo = FakeSampleRepository()
          ..getFailures.add(const Failure.unknown('boom'));
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        const failure = Failure.network();
        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.operationFailure, failure);
      },
    );

    test(
      '初期読み込みがUnknownFailureで失敗した状態でrefreshを呼び取得がAuthFailureで失敗した場合、operationFailureがAuthFailureになる [SMP-V13]',
      () async {
        final repo = FakeSampleRepository()
          ..getFailures.add(const Failure.unknown('boom'));
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        const failure = Failure.auth();
        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼びgetSamplesが「A」「B」を返した場合、samplesがAsyncData([A, B])になりgetSamplesがuserId「u1」で呼ばれる [SMP-V14]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        repo.samples = [a, b];
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(
          state.samples.value!.map((e) => e.name).toList(),
          ['A', 'B'],
        );
        expect(repo.getCalls.last.userId, 'u1');
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V15]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がNotFoundFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNotFoundFailureになる [SMP-V16]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.notFound();
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V17]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.network();
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V18]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.auth();
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        repo.getFailures.add(failure);
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([])の状態でrefreshを呼びgetSamplesが「A」を返した場合、samplesがAsyncData([A])になる [SMP-V19]',
      () async {
        final repo = FakeSampleRepository();
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);
        expect(container.read(sampleViewModelProvider).samples.value, isEmpty);

        final a = _sample('a', 'A');
        repo.samples = [a];
        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
      },
    );
  });

  group('SampleViewModel.createSample()', () {
    test(
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([A, B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V20]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.createSample(name: 'B');
        final state = container.read(sampleViewModelProvider);

        expect(result, isTrue);
        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(repo.createCalls.length, 1);
        expect(repo.createCalls.single.userId, 'u1');
        expect(repo.createCalls.single.name, 'B');
      },
    );

    test(
      'samplesがAsyncData([])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V21]',
      () async {
        final repo = FakeSampleRepository();
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.createSample(name: 'B');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['B']);
        expect(repo.createCalls.single.userId, 'u1');
        expect(repo.createCalls.single.name, 'B');
      },
    );

    test(
      'samplesがAsyncData([A])の状態で名前「A」の作成を呼び作成に成功した場合、samplesは2件でどちらもname「A」でidが互いに異なる [SMP-V22]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.createSample(name: 'A');
        final state = container.read(sampleViewModelProvider);

        final samples = state.samples.value!;
        expect(samples.length, 2);
        expect(samples.every((e) => e.name == 'A'), isTrue);
        expect(samples[0].id, isNot(samples[1].id));
      },
    );

    test(
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V23]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository(initial: [a])
          ..createFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.createSample(name: 'B');
        final state = container.read(sampleViewModelProvider);

        expect(result, isFalse);
        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([])のままでoperationFailureがUnknownFailureになる [SMP-V24]',
      () async {
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository()..createFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.createSample(name: 'B');
        final state = container.read(sampleViewModelProvider);

        expect(result, isFalse);
        expect(state.samples.value, isEmpty);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V25]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.network();
        final repo = FakeSampleRepository(initial: [a])
          ..createFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.createSample(name: 'B');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V26]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.auth();
        final repo = FakeSampleRepository(initial: [a])
          ..createFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.createSample(name: 'B');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );
  });

  group('SampleViewModel.updateSample()', () {
    test(
      'samplesがAsyncData([A, B, C])の状態でBの名前を「X」にする変更を呼び変更に成功した場合、samplesがAsyncData([A, X, C])になりupdateSampleがuserId「u1」・sampleId「Bのid」・name「X」で1回呼ばれる [SMP-V27]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final c = _sample('c', 'C');
        final repo = FakeSampleRepository(initial: [a, b, c]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.updateSample(sampleId: b.id, name: 'X');
        final state = container.read(sampleViewModelProvider);

        expect(result, isTrue);
        expect(
          state.samples.value!.map((e) => e.name).toList(),
          ['A', 'X', 'C'],
        );
        expect(state.samples.value![1].id, b.id);
        expect(repo.updateCalls.length, 1);
        expect(repo.updateCalls.single.userId, 'u1');
        expect(repo.updateCalls.single.sampleId, b.id);
        expect(repo.updateCalls.single.name, 'X');
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でBの名前を「A」にする変更を呼び変更に成功した場合、samplesは2件で上からAのidの「A」、Bのidの「A」になる [SMP-V28]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: b.id, name: 'A');
        final state = container.read(sampleViewModelProvider);

        final samples = state.samples.value!;
        expect(samples.length, 2);
        expect(samples[0].id, a.id);
        expect(samples[0].name, 'A');
        expect(samples[1].id, b.id);
        expect(samples[1].name, 'A');
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの名前を「A」にする変更を呼び変更に成功した場合、samplesの要素は1件でAのidの「A」になる [SMP-V29]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: a.id, name: 'A');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.length, 1);
        expect(state.samples.value!.single.id, a.id);
        expect(state.samples.value!.single.name, 'A');
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V30]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository(initial: [a, b])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.updateSample(sampleId: b.id, name: 'X');
        final state = container.read(sampleViewModelProvider);

        expect(result, isFalse);
        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がNotFoundFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNotFoundFailureになる [SMP-V31]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.notFound();
        final repo = FakeSampleRepository(initial: [a, b])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: b.id, name: 'X');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がNetworkFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNetworkFailureになる [SMP-V32]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.network();
        final repo = FakeSampleRepository(initial: [a, b])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: b.id, name: 'X');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でBの名前を「X」にする変更を呼び変更がAuthFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがAuthFailureになる [SMP-V33]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.auth();
        final repo = FakeSampleRepository(initial: [a, b])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: b.id, name: 'X');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );
  });

  group('SampleViewModel.deleteSample()', () {
    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりdeleteSampleがuserId「u1」・sampleId「Aのid」で1回呼ばれる [SMP-V34]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        await _waitUntil(
          container,
          (s) => (s.samples.value?.length ?? -1) == 1,
        );
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['B']);
        expect(repo.deleteCalls.length, 1);
        expect(repo.deleteCalls.single.userId, 'u1');
        expect(repo.deleteCalls.single.sampleId, a.id);
      },
    );

    test(
      'samplesがAsyncData([A, B, C])の状態でBの削除を呼び削除に成功した場合、samplesがAsyncData([A, C])になる [SMP-V35]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final c = _sample('c', 'C');
        final repo = FakeSampleRepository(initial: [a, b, c]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: b.id);
        await _waitUntil(
          container,
          (s) => (s.samples.value?.length ?? -1) == 2,
        );
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'C']);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([])になる [SMP-V36]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        await _waitUntil(
          container,
          (s) => (s.samples.value?.length ?? -1) == 0,
        );
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value, isEmpty);
      },
    );

    test(
      'samplesがAsyncData([A, B])でRepository上ではAが既に削除されている状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりoperationFailureがnullになる [SMP-V37]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        // Repository 上では A が既に削除されている状態にする
        repo.samples = [b];

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        await _waitUntil(
          container,
          (s) => (s.samples.value?.length ?? -1) == 1,
        );
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['B']);
        expect(state.operationFailure, isNull);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V38]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository(initial: [a, b])
          ..deleteFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除がNotFoundFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNotFoundFailureになる [SMP-V39]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.notFound();
        final repo = FakeSampleRepository(initial: [a, b])
          ..deleteFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除がNetworkFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがNetworkFailureになる [SMP-V40]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.network();
        final repo = FakeSampleRepository(initial: [a, b])
          ..deleteFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除がAuthFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがAuthFailureになる [SMP-V41]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        const failure = Failure.auth();
        final repo = FakeSampleRepository(initial: [a, b])
          ..deleteFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A', 'B']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼び、読み込みが完了していない場合、samplesはAsyncData([A])のままになる [SMP-V42]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final gate = Completer<void>();
        repo.getGate = gate;
        final notifier = container.read(sampleViewModelProvider.notifier);
        final refreshFuture = notifier.refresh();
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);

        gate.complete();
        await refreshFuture;
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び、その完了前にCの作成を呼んで、作成がCを返し削除も成功した場合、両方の完了後にsamplesがAsyncData([B, C])になる [SMP-V43]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final deleteGate = Completer<void>();
        repo.deleteGate = deleteGate;

        // 削除の repo 呼び出しが deleteGate で止まっている間に作成を行う
        final deleteFuture = notifier.deleteSample(sampleId: a.id);
        await notifier.createSample(name: 'C');

        deleteGate.complete();
        await deleteFuture;
        await _waitUntil(
          container,
          (s) => (s.samples.value?.length ?? -1) == 2,
        );
        final state = container.read(sampleViewModelProvider);

        expect(
          state.samples.value!.map((e) => e.name).toSet(),
          {'B', 'C'},
        );
      },
    );

    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び、その完了前にrefreshを呼び、refreshのgetSamplesが「A」「B」を、削除後のgetSamplesが「B」を返し、refreshの方が後に完了した場合、両方の完了後にsamplesがAsyncData([B])になる [SMP-V44]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        // 1回目の getSamples 呼び出し（外側の refresh）は
        // refreshGate を解放するまで完了しない。返す値は削除前の「A」「B」。
        // 2回目の getSamples 呼び出し（削除の内部の refresh）はゲートなしで
        // 即座に完了し、削除後の「B」を返す。
        final refreshGate = Completer<void>();
        repo.getResponses.addAll([
          (gate: refreshGate, returnValue: [a, b]),
          (gate: null, returnValue: [b]),
        ]);

        final refreshFuture = notifier.refresh();
        await notifier.deleteSample(sampleId: a.id);
        // 削除の内部の refresh（2回目の getSamples）が完了するのを待つ
        await _waitUntil(
          container,
          (s) => (s.samples.value?.length ?? -1) == 1,
        );

        refreshGate.complete();
        await refreshFuture;
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['B']);
      },
    );
  });
}
