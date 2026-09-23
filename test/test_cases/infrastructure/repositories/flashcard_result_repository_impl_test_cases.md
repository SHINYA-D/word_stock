# flashcard_result_repository_impl_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/flashcard_result_repository_impl.dart |
| クラス名 | FlashcardResultRepositoryImpl |
| テスト対象メソッド | getFlashcardResults() / saveFlashcardResult() / _mapException()(private、saveFlashcardResult経由で間接的に検証) |

## 実行環境について

`FlashcardResultRepositoryImpl` は SQLite(sqflite)・Firestore・ネットワーク接続監視に依存するため、
以下の方針で Dart Pure Test として実行できるようにしている。

- **SQLite**: `sqflite_common_ffi` を使い、実際の SQLite エンジンをテスト専用の一時ディレクトリ上の
  ファイルとして使用する（`FlashcardResultLocalDataSource` / `SyncQueueDataSource` /
  `DatabaseHelper` は実クラスをそのまま使用）。
- **Firestore**: `FirestoreDataSource` を `implements` した手書きフェイク
  `test/helpers/fake_infrastructure.dart` の `FakeFirestoreDataSource` を使用し、
  実際の Firebase 通信は行わない。呼び出し内容を記録し検証する。
- **ネットワーク接続**: `ConnectivityMonitor` を `implements` した
  `FakeConnectivityMonitor` でオンライン/オフラインを固定する。
- ローカル層の例外・トランザクション失敗は、対象テーブルを `DROP TABLE` して
  クエリ自体を失敗させることで再現している。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | データが存在する場合、Rightで成績一覧が返る | 正常系 | getFlashcardResults() | ✅ |
| 2 | folderIdを指定した場合、そのフォルダの成績のみ返る | 正常系 | getFlashcardResults() | ✅ |
| 3 | 該当データが無い場合、Rightで空リストが返る | 境界値 | getFlashcardResults() | ✅ |
| 4 | ローカル取得中に例外が発生した場合、Failure.unknownが返る | 異常系 | getFlashcardResults() | ✅ |
| 5 | 保存が成功した場合、ローカルにsynced状態で保存されFirestoreにも書き込まれRightが返る | 正常系 | saveFlashcardResult() | ✅ |
| 6 | FirebaseExceptionのcodeがunavailableの場合、Failure.networkが返る | 異常系 | saveFlashcardResult() / _mapException() | ✅ |
| 7 | FirebaseExceptionのcodeがnetwork-request-failedの場合、Failure.networkが返る | 異常系 | saveFlashcardResult() / _mapException() | ✅ |
| 8 | FirebaseExceptionのcodeがその他でmessageがある場合、Failure.unknown(message)が返る | 異常系 | saveFlashcardResult() / _mapException() | ✅ |
| 9 | FirebaseExceptionのmessageがnullの場合、Failure.unknown(code)が返る | 境界値 | saveFlashcardResult() / _mapException() | ✅ |
| 10 | FirebaseException以外の例外が発生した場合、Failure.unknownが返る | 異常系 | saveFlashcardResult() | ✅ |
| 11 | (オフライン)保存した場合、ローカルにpending状態で保存されsync_queueにcreate登録されRightが返り、Firestoreへは書き込まれない | 正常系 | saveFlashcardResult() | ✅ |
| 12 | (オフライン)sync_queueのpayloadに保存内容が正しく記録される | 正常系 | saveFlashcardResult() | ✅ |
| 13 | (オフライン)トランザクション内で例外が発生した場合、Failure.unknownが返りロールバックされ何も保存されない | 異常系 | saveFlashcardResult() | ✅ |

## テストケース詳細

### テストケース1: データが存在する場合、Rightで成績一覧が返る
- **カテゴリ**: 正常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: `folder-1`に紐づく成績データ2件がローカルDBに存在する。
- **入力値・テスト条件**: `userId`のみ指定（`folderId`は未指定）。
- **操作手順**: `repository.getFlashcardResults(userId: userId)`を呼ぶ。
- **期待結果**: `Right`が返り、登録した2件のIDが両方含まれる。

### テストケース2: folderIdを指定した場合、そのフォルダの成績のみ返る
- **カテゴリ**: 正常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: `folder-1`に1件、`folder-2`に1件の成績データが存在する。
- **入力値・テスト条件**: `folderId: 'folder-1'`を指定。
- **操作手順**: `repository.getFlashcardResults(userId: userId, folderId: 'folder-1')`を呼ぶ。
- **期待結果**: `folder-1`の1件のみが返る。

### テストケース3: 該当データが無い場合、Rightで空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: getFlashcardResults()
- **事前条件**: データが1件も無い状態で、存在しない`folderId`を指定する。
- **入力値・テスト条件**: `folderId: 'no-such-folder'`。
- **操作手順**: `repository.getFlashcardResults(userId: userId, folderId: 'no-such-folder')`を呼ぶ。
- **期待結果**: `Right([])`が返る（例外にはならない）。

### テストケース4: ローカル取得中に例外が発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: `flashcard_results`テーブルを`DROP TABLE`し、クエリが失敗する状態にする。
- **入力値・テスト条件**: 通常の`userId`。
- **操作手順**: `repository.getFlashcardResults(userId: userId)`を呼ぶ。
- **期待結果**: `Left(Failure.unknown(...))`が返る（`UnknownFailure`型であることを検証）。テスト後にテーブルを復元する。

### テストケース5: 保存が成功した場合、ローカルにsynced状態で保存されFirestoreにも書き込まれRightが返る
- **カテゴリ**: 正常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: `FakeConnectivityMonitor`をオンラインに設定（デフォルト）。
- **入力値・テスト条件**: `folderId: 'folder-1', totalCount: 10, correctCount: 7`。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `Right(FlashcardResult)`が返り、ローカルDBの`syncStatus`が`'synced'`、`FakeFirestoreDataSource.writtenFlashcardResults`に書き込まれ、`sync_queue`には何も登録されない。

### テストケース6: FirebaseExceptionのcodeがunavailableの場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult() / _mapException()
- **事前条件**: オンライン状態。`FakeFirestoreDataSource.exceptionToThrow`に`FirebaseException(code: 'unavailable')`を設定。
- **入力値・テスト条件**: 通常の保存パラメータ。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `Left(Failure.network())`が返る。

### テストケース7: FirebaseExceptionのcodeがnetwork-request-failedの場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult() / _mapException()
- **事前条件**: オンライン状態。`exceptionToThrow`に`FirebaseException(code: 'network-request-failed')`を設定。
- **入力値・テスト条件**: 通常の保存パラメータ。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `Left(Failure.network())`が返る。

### テストケース8: FirebaseExceptionのcodeがその他でmessageがある場合、Failure.unknown(message)が返る
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult() / _mapException()
- **事前条件**: オンライン状態。`exceptionToThrow`に`FirebaseException(code: 'permission-denied', message: 'permission denied message')`を設定。
- **入力値・テスト条件**: 通常の保存パラメータ。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `Left(Failure.unknown('permission denied message'))`が返る。

### テストケース9: FirebaseExceptionのmessageがnullの場合、Failure.unknown(code)が返る
- **カテゴリ**: 境界値
- **対象メソッド**: saveFlashcardResult() / _mapException()
- **事前条件**: オンライン状態。`exceptionToThrow`に`message`未指定（null）の`FirebaseException(code: 'permission-denied')`を設定。
- **入力値・テスト条件**: 通常の保存パラメータ。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `e.message ?? e.code`のフォールバックにより`Left(Failure.unknown('permission-denied'))`が返る。

### テストケース10: FirebaseException以外の例外が発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: オンライン状態。`exceptionToThrow`に通常の`Exception('boom')`を設定。
- **入力値・テスト条件**: 通常の保存パラメータ。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: 汎用`catch (e)`節に入り、`Left(Failure.unknown(...))`（`UnknownFailure`型）が返る。

### テストケース11: (オフライン)保存した場合、ローカルにpending状態で保存されsync_queueにcreate登録されRightが返り、Firestoreへは書き込まれない
- **カテゴリ**: 正常系
- **対象メソッド**: saveFlashcardResult()（オフライン分岐）
- **事前条件**: `FakeConnectivityMonitor.setOnline(false)`。
- **入力値・テスト条件**: `folderId: 'folder-1', totalCount: 10, correctCount: 7`。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `Right`が返り、ローカルDBの`syncStatus`が`'pending'`、`sync_queue`に`table_name = 'flashcard_results', operation = 'create'`の行が1件登録され、`FakeFirestoreDataSource.writtenFlashcardResults`は空のまま。

### テストケース12: (オフライン)sync_queueのpayloadに保存内容が正しく記録される
- **カテゴリ**: 正常系
- **対象メソッド**: saveFlashcardResult()（オフライン分岐）
- **事前条件**: オフライン状態。
- **入力値・テスト条件**: `folderId: 'folder-1', totalCount: 10, correctCount: 7`。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼び、`sync_queue`の`payload`列をJSONデコードする。
- **期待結果**: `payload`の`folderId`/`totalCount`/`correctCount`/`date`/`updatedAt`が保存した`FlashcardResult`の値と一致する。

### テストケース13: (オフライン)トランザクション内で例外が発生した場合、Failure.unknownが返りロールバックされ何も保存されない
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult()（オフライン分岐）
- **事前条件**: オフライン状態。`sync_queue`テーブルを`DROP TABLE`し、`enqueueInTransaction`が失敗する状態にする。
- **入力値・テスト条件**: 通常の保存パラメータ。
- **操作手順**: `repository.saveFlashcardResult(...)`を呼ぶ。
- **期待結果**: `db.transaction`内で例外が発生し全体がロールバックされるため、`flashcard_results`テーブルへのinsertも残らず（`findByUserId`が空）、`Left(Failure.unknown(...))`が返る。テスト後にテーブルを復元する。

## 対象外

なし（すべての分岐・catch節をテストで網羅している）。
