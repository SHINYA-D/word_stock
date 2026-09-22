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

/// 仕様書（docs/detailed_design/presentation/sample/sample_page.md）の
/// 「ログイン中のユーザーの id は u1 とする」に合わせたテスト用ユーザー。
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
      'samplesがAsyncError(UnknownFailure)の状態で、Aの1件が取得できるようにしてからrefreshを呼んだ場合、samplesがAsyncData([A])になる [SMP-V08]',
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
      },
    );

    test(
      'samplesがAsyncError(UnknownFailure)の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesがAsyncError(UnknownFailure)になる [SMP-V09]',
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
      'samplesがAsyncData([A])の状態でRepositoryにBを追加しrefreshを呼んだ場合、samplesがAsyncData([A, B])になる [SMP-V10]',
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
      },
    );

    test(
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V11]',
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
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V12]',
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
      'samplesがAsyncData([A])の状態でrefreshを呼び取得がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V13]',
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
  });

  group('SampleViewModel.createSample()', () {
    test(
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成に成功した場合、samplesがAsyncData([A, B])になりcreateSampleがuserId「u1」・name「B」で1回呼ばれる [SMP-V14]',
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
      'samplesがAsyncData([])の状態で名前「A」の作成を呼び作成に成功した場合、samplesがAsyncData([A])になる [SMP-V15]',
      () async {
        final repo = FakeSampleRepository();
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.createSample(name: 'A');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
      },
    );

    test(
      'samplesがAsyncData([A])の状態で名前「A」の作成を呼び作成に成功した場合、samplesが名前「A」の要素を2つ持つAsyncDataになる [SMP-V16]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.createSample(name: 'A');
        final state = container.read(sampleViewModelProvider);

        expect(
          state.samples.value!.where((e) => e.name == 'A').length,
          2,
        );
      },
    );

    test(
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V17]',
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
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V18]',
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
      'samplesがAsyncData([A])の状態で名前「B」の作成を呼び作成がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V19]',
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
      'samplesがAsyncData([A, B])の状態でAの名前を「C」にする変更を呼び変更に成功した場合、samplesがAsyncData([C, B])になりupdateSampleがuserId「u1」・sampleId「Aのid」・name「C」で1回呼ばれる [SMP-V20]',
      () async {
        final a = _sample('a', 'A');
        final b = _sample('b', 'B');
        final repo = FakeSampleRepository(initial: [a, b]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.updateSample(sampleId: a.id, name: 'C');
        final state = container.read(sampleViewModelProvider);

        expect(result, isTrue);
        expect(
          state.samples.value!.map((e) => e.name).toList(),
          ['C', 'B'],
        );
        expect(state.samples.value!.first.id, a.id);
        expect(repo.updateCalls.length, 1);
        expect(repo.updateCalls.single.userId, 'u1');
        expect(repo.updateCalls.single.sampleId, a.id);
        expect(repo.updateCalls.single.name, 'C');
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの名前を「A」にする変更を呼び変更に成功した場合、samplesの要素は1件で名前は「A」になる [SMP-V21]',
      () async {
        final a = _sample('a', 'A');
        final repo = FakeSampleRepository(initial: [a]);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: a.id, name: 'A');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.length, 1);
        expect(state.samples.value!.single.name, 'A');
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がUnknownFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがUnknownFailureになる [SMP-V22]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.unknown('boom');
        final repo = FakeSampleRepository(initial: [a])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        final result = await notifier.updateSample(sampleId: a.id, name: 'C');
        final state = container.read(sampleViewModelProvider);

        expect(result, isFalse);
        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がNotFoundFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNotFoundFailureになる [SMP-V23]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.notFound();
        final repo = FakeSampleRepository(initial: [a])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: a.id, name: 'C');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V24]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.network();
        final repo = FakeSampleRepository(initial: [a])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: a.id, name: 'C');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの名前を「C」にする変更を呼び変更がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V25]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.auth();
        final repo = FakeSampleRepository(initial: [a])
          ..updateFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.updateSample(sampleId: a.id, name: 'C');
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );
  });

  group('SampleViewModel.deleteSample()', () {
    test(
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([B])になりdeleteSampleがuserId「u1」・sampleId「Aのid」で1回呼ばれる [SMP-V26]',
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
      'samplesがAsyncData([A])の状態でAの削除を呼び削除に成功した場合、samplesがAsyncData([])になる [SMP-V27]',
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
      'samplesがAsyncData([A, B])の状態でAの削除を呼び削除がUnknownFailureで失敗した場合、samplesはAsyncData([A, B])のままでoperationFailureがUnknownFailureになる [SMP-V28]',
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
      'samplesがAsyncData([A])の状態でAの削除を呼び削除がNetworkFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがNetworkFailureになる [SMP-V29]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.network();
        final repo = FakeSampleRepository(initial: [a])
          ..deleteFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );

    test(
      'samplesがAsyncData([A])の状態でAの削除を呼び削除がAuthFailureで失敗した場合、samplesはAsyncData([A])のままでoperationFailureがAuthFailureになる [SMP-V30]',
      () async {
        final a = _sample('a', 'A');
        const failure = Failure.auth();
        final repo = FakeSampleRepository(initial: [a])
          ..deleteFailures.add(failure);
        final container = _makeContainer(repo);
        await _waitForInitialLoad(container);

        final notifier = container.read(sampleViewModelProvider.notifier);
        await notifier.deleteSample(sampleId: a.id);
        final state = container.read(sampleViewModelProvider);

        expect(state.samples.value!.map((e) => e.name).toList(), ['A']);
        expect(state.operationFailure, failure);
      },
    );
  });
}
