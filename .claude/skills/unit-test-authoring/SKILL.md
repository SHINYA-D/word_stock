---
name: unit-test-authoring
description: WordStockでビジネスロジック層（UseCase / Repository実装 / Entity / ViewModel / core/utils）のDart単体テスト（test()）を書くときの作法・雛形集。fpdartのEither検証、ProviderContainerでのViewModelテスト、sqflite_common_ffiのセットアップ、境界値の洗い出し方を含む。単体テストの新規作成・修正時に参照する。
---

# 単体テストの書き方（WordStock）

CLAUDE.md「## テスト方針」の実装ガイド。`test()` のみ使用（`testWidgets()` 不可）。

## 基本形

```dart
import 'package:flutter_test/flutter_test.dart'; // test/expect/group を提供（flutter プロジェクトの標準）

void main() {
  group('SomeClass.method', () {
    test('正常な入力の場合、Right が返る', () async {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

- **1テスト = 1振る舞い**。`group()` はメソッド単位
- 順序は 正常系 → 異常系 → 境界値
- テスト名は「○○の場合、△△が起きる」

## fpdart `Either<Failure, T>` の検証

```dart
final result = await repository.createWord(...);

expect(result.isRight(), isTrue);
result.match((f) => fail('Right が返るはず: $f'), (word) => expect(word.id, 'w1'));

// 失敗
expect(result.isLeft(), isTrue);
result.match((f) => expect(f, const Failure.network()), (_) => fail('Left が返るはず'));
// または
expect(result, equals(const Left(Failure.network())));
```

`Failure` は Freezed sealed（`network` / `auth` / `notFound` / `unknown(message)`）。

## ViewModel テスト（ProviderContainer）

Widget を pump しない。`ProviderContainer` で provider を override して notifier を直接叩く。

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

ProviderContainer makeContainer({List<Override> overrides = const []}) {
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

test('空リストで start した場合、即 finished 状態になる', () async {
  final c = makeContainer(overrides: [
    saveFlashcardResultUseCaseProvider.overrideWithValue(_FakeSaveUseCase()),
    currentUserProvider.overrideWithValue(testUser),
  ]);
  final vm = c.read(flashcardModeViewModelProvider.notifier);

  vm.start(const []);

  expect(c.read(flashcardModeViewModelProvider).isFinished, isTrue);
});
```

- `@riverpod class` の `build()` が `Future`/`FutureOr` を返すなら `await c.read(provider.future);` で初期化を待つ
- `Future.microtask(() => _load())` 型の初期ロードは `await Future<void>.delayed(Duration.zero);` で流す
- 依存の UseCase / Repository は **手書きの Fake クラス**（`implements XxxUseCase`）。mockito/mocktail 不可
- provider 名・notifier クラス名は対象 ViewModel ファイルと同ディレクトリの `*.g.dart` で確認

## Repository 実装テスト（実 SQLite + Fake Firestore）

お手本: `test/infrastructure/repositories/folder_repository_impl_test.dart`

```dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

setUpAll(() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  // DatabaseHelper は 'wordstock.db' 固定名 → テストファイル専用の一時ディレクトリでロック競合回避
  final tempDir = await Directory.systemTemp.createTemp('xxx_repository_test_');
  await databaseFactory.setDatabasesPath(tempDir.path);
});

setUp(() async {
  dbHelper = DatabaseHelper();
  final db = await dbHelper.database;
  for (final t in [FolderTable.tableName, WordTable.tableName,
      FlashcardResultTable.tableName, SyncQueueTable.tableName]) {
    await db.delete(t); // テスト間の汚染防止
  }
  fakeRemote = FakeFirestoreDataSource();          // test/helpers/fake_infrastructure.dart
  fakeConnectivity = FakeConnectivityMonitor(online: true);
  repository = XxxRepositoryImpl(/* 実 LocalDataSource + fakeRemote + fakeConnectivity */);
});
```

検証観点:
- **オンライン**: ローカル DB と `fakeRemote.writtenXxx` / `deletedXxx` の両方に反映されるか
- **オフライン**（`fakeConnectivity.setOnline(false)`）: ローカル DB のみ + `sync_queue` テーブルに行が入るか、`fakeRemote` は空か
- **例外**: `fakeRemote.exceptionToThrow = FirebaseException(plugin:'firestore', code:'unavailable')` → `Failure.network()`
- `createdAt` の保持（`existing?.createdAt ?? now`）

## sync_service テスト

`FakeFirestoreDataSource` に読み取り系メソッドが無い場合は、テスト内で `implements FirestoreDataSource` の
拡張 Fake を作る（取得結果を差し込めるフィールドを追加）。競合解決は
「ローカル `syncStatus == 'pending'` を保持」「`localUpdatedAt.isAfter(remoteUpdatedAt)` を保持」の
両分岐を、updatedAt を1秒ずらした2ケースで確認。スロットルは `lastSyncedAt` を5分前/5分以内でセットして分岐確認。

## 境界値の洗い出し

| 型 | 見るべき境界 |
|----|------------|
| List | 空 / 1件 / 複数 / （上限があれば）上限ちょうど・上限+1 |
| String | 空文字 / 空白のみ / 前後空白 / 最大長 / 最大長+1 |
| int（カウント） | 0 / 1 / 最大 |
| DateTime | 同値 / 1マイクロ秒前後 / null |
| nullable | null / 非null |
| 分岐フラグ（isSubmitting 等） | 立っている / いない 両方から呼ぶ |

## やらないこと（無価値テスト）

- コンストラクタを呼ぶだけ / Freezed の getter・copyWith・==・toString
- 定数クラス、ロジックのない単純委譲（use_case は「委譲していること」1ケースのみ許容）
- private を reflection や `@visibleForTesting` で無理に開いて呼ぶ

## 実行

```bash
bash scripts/test_harness.sh test/<生成したパス>_test.dart
```
`fvm flutter test --coverage` は直接叩かない（ハーネスが限定分母フィルタと報告を行う）。
