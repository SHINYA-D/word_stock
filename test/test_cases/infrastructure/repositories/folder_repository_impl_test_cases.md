# folder_repository_impl_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/folder_repository_impl.dart |
| クラス名 | FolderRepositoryImpl |
| テスト対象メソッド | deleteFolder() / _collectFolderIdsRecursively()(private、deleteFolder経由で間接的に検証) |

## 実行環境について

`FolderRepositoryImpl` は SQLite(sqflite)・Firestore・ネットワーク接続監視に依存するため、
以下の方針で Dart Pure Test として実行できるようにしている。

- **SQLite**: `sqflite_common_ffi` を dev_dependency として追加し、実際の SQLite エンジンを
  インメモリではなくテスト専用の一時ディレクトリ上のファイルとして使用する
  (`FolderLocalDataSource` / `WordLocalDataSource` / `FlashcardResultLocalDataSource` /
  `SyncQueueDataSource` / `DatabaseHelper` は実クラスをそのまま使用)。
- **Firestore**: `FirestoreDataSource` を `implements` した手書きフェイク
  `test/helpers/fake_infrastructure.dart` の `FakeFirestoreDataSource` を使用し、
  実際の Firebase 通信は行わない。呼び出し内容を記録し検証する。
- **ネットワーク接続**: `ConnectivityMonitor` を `implements` した
  `FakeConnectivityMonitor` でオンライン/オフラインを固定する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 子フォルダ・単語・成績データを持たない単一フォルダを削除した場合、ローカルとリモートの両方からフォルダが削除される | 正常系 | deleteFolder() | ✅ |
| 2 | フォルダ配下の単語がある場合、単語もローカル・リモートの両方から削除される | 正常系 | deleteFolder() | ✅ |
| 3 | フォルダ配下の成績データがある場合、成績データもローカル・リモートの両方から削除される | 正常系 | deleteFolder() | ✅ |
| 4 | サブフォルダが存在する場合、サブフォルダも再帰的に削除される | 正常系 | deleteFolder() / _collectFolderIdsRecursively() | ✅ |
| 5 | 孫フォルダまで存在する深いネストの場合も、すべての階層が再帰的に削除される | エッジケース | deleteFolder() / _collectFolderIdsRecursively() | ✅ |
| 6 | 兄弟フォルダが存在する場合、削除対象ではない兄弟フォルダは削除されない | エッジケース | deleteFolder() | ✅ |
| 7 | リモート削除でFirebaseExceptionが発生した場合、Failure.networkが返る | 異常系 | deleteFolder() | ✅ |
| 8 | (オフライン)子フォルダ・単語・成績データを持たない単一フォルダを削除した場合、ローカルから削除されsync_queueにdelete登録される | 正常系 | deleteFolder() | ✅ |
| 9 | (オフライン)フォルダ配下の単語・成績データがある場合、それらもローカルから削除されsync_queueにdelete登録される | 正常系 | deleteFolder() | ✅ |
| 10 | (オフライン)孫フォルダまで存在する深いネストの場合も、すべての階層が再帰的に削除されsync_queueに登録される | エッジケース | deleteFolder() / _collectFolderIdsRecursively() | ✅ |

## テストケース詳細

### テストケース1: 子フォルダ・単語・成績データを持たない単一フォルダを削除した場合、ローカルとリモートの両方からフォルダが削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **入力条件**: フォルダ`root`のみが存在し、子フォルダ・単語・成績データは無い。オンライン状態。
- **期待値**: `Right(unit)`が返り、ローカルDBから`root`が削除され、`FakeFirestoreDataSource.deletedFolders`に`root`が記録される。

### テストケース2: フォルダ配下の単語がある場合、単語もローカル・リモートの両方から削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **入力条件**: フォルダ`root`配下に単語2件が存在。オンライン状態。
- **期待値**: ローカルDBから単語が全件削除され、`deletedWords`に両方の`wordId`が記録される。

### テストケース3: フォルダ配下の成績データがある場合、成績データもローカル・リモートの両方から削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **入力条件**: フォルダ`root`配下に成績データ1件が存在。オンライン状態。
- **期待値**: ローカルDBから成績データが削除され、`deletedFlashcardResults`に記録される。

### テストケース4: サブフォルダが存在する場合、サブフォルダも再帰的に削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder() / _collectFolderIdsRecursively()
- **入力条件**: `root`の子に`child`が存在。
- **期待値**: `root`・`child`とも削除され、`deletedFolders`に両方のIDが記録される。

### テストケース5: 孫フォルダまで存在する深いネストの場合も、すべての階層が再帰的に削除される
- **カテゴリ**: エッジケース
- **対象メソッド**: deleteFolder() / _collectFolderIdsRecursively()
- **入力条件**: `root` -> `child` -> `grandchild`の3階層。`grandchild`配下に単語・成績データも存在。
- **期待値**: 3階層すべてのフォルダ、および`grandchild`配下の単語・成績データがローカル・リモート両方から削除される。

### テストケース6: 兄弟フォルダが存在する場合、削除対象ではない兄弟フォルダは削除されない
- **カテゴリ**: エッジケース
- **対象メソッド**: deleteFolder()
- **入力条件**: `root`の子に`child-a`、`root`とは無関係な`sibling`フォルダが存在。
- **期待値**: `sibling`はローカルに残り、`deletedFolders`には`root`・`child-a`のみが記録される。

### テストケース7: リモート削除でFirebaseExceptionが発生した場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: deleteFolder()
- **入力条件**: `FakeFirestoreDataSource.exceptionToThrow`に`FirebaseException(code: 'unavailable')`を設定。
- **期待値**: `Left(Failure.network())`が返る。

### テストケース8: (オフライン)子フォルダ・単語・成績データを持たない単一フォルダを削除した場合、ローカルから削除されsync_queueにdelete登録される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()(オフライン分岐)
- **入力条件**: フォルダ`root`のみ存在。`FakeConnectivityMonitor`をオフラインに設定。
- **期待値**: ローカルDBから`root`が削除され、`sync_queue`テーブルに`table_name = 'folders', record_id = 'root', operation = 'delete'`の行が1件登録される。リモートへの呼び出しは行われない(`deletedFolders`は空)。

### テストケース9: (オフライン)フォルダ配下の単語・成績データがある場合、それらもローカルから削除されsync_queueにdelete登録される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()(オフライン分岐)
- **入力条件**: フォルダ`root`配下に単語1件・成績データ1件が存在。オフライン状態。
- **期待値**: 単語・成績データがローカルDBから削除され、それぞれ`sync_queue`に`delete`操作として登録される。

### テストケース10: (オフライン)孫フォルダまで存在する深いネストの場合も、すべての階層が再帰的に削除されsync_queueに登録される
- **カテゴリ**: エッジケース
- **対象メソッド**: deleteFolder() / _collectFolderIdsRecursively()(オフライン分岐)
- **入力条件**: `root` -> `child` -> `grandchild`の3階層。`grandchild`配下に単語1件が存在。オフライン状態。
- **期待値**: 3階層すべてのフォルダと単語がローカルDBから削除され、それぞれ`sync_queue`に`delete`操作として登録される。

## 補足: レビュー中に発見・修正した実装バグ

テスト作成の過程で、`deleteFolder()`のオフライン分岐に、`db.transaction((txn) async { ... })`の
コールバック内部から`_wordLocal.findByFolderId` / `_testResultLocal.findByUserId`
(いずれも`_dbHelper.database`経由でトランザクション**外**のDB接続を使う)を直接呼び出しており、
進行中のトランザクションのロックと競合してsqfliteが確実にデッドロックするバグが見つかった。

`lib/infrastructure/repositories/folder_repository_impl.dart`の実装を、削除対象の
word/testResultのIDを`db.transaction()`を開始する**前**に収集し、トランザクション内では
`txn.delete`と`syncQueue.enqueueInTransaction`のみを行うように修正済み。上記テストケース8〜10は
この修正後の正しい挙動を検証している。
