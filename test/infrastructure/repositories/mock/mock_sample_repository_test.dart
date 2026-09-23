import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/sample.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_sample_repository.dart';

// 仕様書: docs/detailed_design/presentation/sample/sample_page.md
// 対象: 5章「リポジトリ契約（SampleRepository）」 SMP-R01〜SMP-R12
//
// MockSampleRepository はコンストラクタで既定データ（別 userId）を用意するが、
// このテストでは userId「u1」「u2」を使い、既定データには依存しない。
void main() {
  const u1 = 'u1';
  const u2 = 'u2';

  late MockSampleRepository repository;

  setUp(() {
    repository = MockSampleRepository();
  });

  Future<Sample> createA({String userId = u1}) async {
    final result = await repository.createSample(userId: userId, name: 'A');
    return result.match((_) => fail('Right が返るはず'), (s) => s);
  }

  Future<Sample> createB({String userId = u1}) async {
    final result = await repository.createSample(userId: userId, name: 'B');
    return result.match((_) => fail('Right が返るはず'), (s) => s);
  }

  group('getSamples', () {
    test('u1に「A」「B」がある場合、Right([A, B])が作成順で返る [SMP-R01]', () async {
      final a = await createA();
      final b = await createB();

      final result = await repository.getSamples(userId: u1);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [a.id, b.id]),
      );
    });

    test('u1にサンプルがない場合、Right([])が返る [SMP-R02]', () async {
      final result = await repository.getSamples(userId: u1);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples, isEmpty),
      );
    });

    test('u1に「A」、u2に「B」がある状態でuserId「u2」で取得した場合、Right([B])が返る [SMP-R03]',
        () async {
      await createA(userId: u1);
      final b = await createB(userId: u2);

      final result = await repository.getSamples(userId: u2);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [b.id]),
      );
    });
  });

  group('createSample', () {
    test(
        'u1に「A」がある状態でuserId「u1」・name「B」で作成した場合、'
        'Right(Sample)が返りnameは「B」、idは空でない、createdAtとupdatedAtが等しい。'
        'その後のgetSamples(u1)はRight([A, B]) [SMP-R04]', () async {
      final a = await createA();

      final result = await repository.createSample(userId: u1, name: 'B');

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (sample) {
          expect(sample.name, 'B');
          expect(sample.id, isNotEmpty);
          expect(sample.createdAt, sample.updatedAt);
        },
      );

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [
          a.id,
          result.match((_) => fail('Right が返るはず'), (s) => s.id),
        ]),
      );
    });

    test(
        'userId「u1」・name「B」で2回作成した場合、2回の戻り値のidが異なる。'
        'その後のgetSamples(u1)は名前「B」の要素を2つ含む [SMP-R05]', () async {
      final first = await repository.createSample(userId: u1, name: 'B');
      final second = await repository.createSample(userId: u1, name: 'B');

      final firstId = first.match((_) => fail('Right が返るはず'), (s) => s.id);
      final secondId = second.match((_) => fail('Right が返るはず'), (s) => s.id);
      expect(firstId, isNot(secondId));

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) =>
            expect(samples.where((s) => s.name == 'B'), hasLength(2)),
      );
    });

    test(
        'u1に「A」がある状態でuserId「u2」・name「B」で作成した場合、'
        'その後のgetSamples(u1)はRight([A])のまま [SMP-R06]', () async {
      final a = await createA(userId: u1);

      await repository.createSample(userId: u2, name: 'B');

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [a.id]),
      );
    });
  });

  group('updateSample', () {
    test(
        'u1に「A」「B」がある状態でuserId「u1」・sampleId「Aのid」・name「C」で変更した場合、'
        'Right(Sample)が返り、idはAのid、nameは「C」、createdAtはAのcreatedAtと等しい、'
        'updatedAtはAのupdatedAtより後。その後のgetSamples(u1)はRight([C, B]) [SMP-R07]',
        () async {
      final a = await createA();
      final b = await createB();

      final result = await repository.updateSample(
        userId: u1,
        sampleId: a.id,
        name: 'C',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (sample) {
          expect(sample.id, a.id);
          expect(sample.name, 'C');
          expect(sample.createdAt, a.createdAt);
          expect(sample.updatedAt.isAfter(a.updatedAt), isTrue);
        },
      );

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) {
          expect(samples.map((s) => s.id).toList(), [a.id, b.id]);
          expect(samples.first.name, 'C');
          expect(samples.last.name, 'B');
        },
      );
    });

    test(
        'u1に「A」がある状態で、存在しないsampleIdで変更した場合、Left(NotFoundFailure)。'
        'その後のgetSamples(u1)はRight([A])のまま [SMP-R08]', () async {
      final a = await createA();

      final result = await repository.updateSample(
        userId: u1,
        sampleId: 'not-exist',
        name: 'C',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Left が返るはず'),
      );

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [a.id]),
      );
    });

    test(
        'u2に「B」がある状態でuserId「u1」・sampleId「Bのid」・name「C」で変更した場合、'
        'Left(NotFoundFailure)。その後のgetSamples(u2)はRight([B])のまま [SMP-R09]', () async {
      final b = await createB(userId: u2);

      final result = await repository.updateSample(
        userId: u1,
        sampleId: b.id,
        name: 'C',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<NotFoundFailure>()),
        (_) => fail('Left が返るはず'),
      );

      final after = await repository.getSamples(userId: u2);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) {
          expect(samples.map((s) => s.id).toList(), [b.id]);
          expect(samples.single.name, 'B');
        },
      );
    });
  });

  group('deleteSample', () {
    test(
        'u1に「A」「B」がある状態でuserId「u1」・sampleId「Aのid」で削除した場合、Right(unit)。'
        'その後のgetSamples(u1)はRight([B]) [SMP-R10]', () async {
      final a = await createA();
      final b = await createB();

      final result =
          await repository.deleteSample(userId: u1, sampleId: a.id);

      expect(result.isRight(), isTrue);

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [b.id]),
      );
    });

    test(
        'u1に「A」がある状態で、存在しないsampleIdで削除した場合、Right(unit)。'
        'その後のgetSamples(u1)はRight([A])のまま [SMP-R11]', () async {
      final a = await createA();

      final result =
          await repository.deleteSample(userId: u1, sampleId: 'not-exist');

      expect(result.isRight(), isTrue);

      final after = await repository.getSamples(userId: u1);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [a.id]),
      );
    });

    test(
        'u2に「B」がある状態でuserId「u1」・sampleId「Bのid」で削除した場合、Right(unit)。'
        'その後のgetSamples(u2)はRight([B])のまま [SMP-R12]', () async {
      final b = await createB(userId: u2);

      final result =
          await repository.deleteSample(userId: u1, sampleId: b.id);

      expect(result.isRight(), isTrue);

      final after = await repository.getSamples(userId: u2);
      after.match(
        (_) => fail('Right が返るはず'),
        (samples) => expect(samples.map((s) => s.id).toList(), [b.id]),
      );
    });
  });
}
