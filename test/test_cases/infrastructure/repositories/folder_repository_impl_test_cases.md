# folder_repository_impl_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/folder_repository_impl.dart |
| クラス名 | FolderRepositoryImpl |
| テスト対象メソッド | getFolders() / createFolder() / updateFolder() / deleteFolder() / _collectFolderIdsRecursively()(private、deleteFolder経由で間接的に検証) / _mapException()(private、create/update/delete経由で間接的に検証) |

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
| 11 | 親フォルダIDを指定した場合、その配下のフォルダ一覧がローカルDBから取得できる | 正常系 | getFolders() | ✅ |
| 12 | 該当するフォルダが存在しない場合、空リストが返る | 境界値 | getFolders() | ✅ |
| 13 | ローカルDBアクセスで例外が発生した場合、Failure.unknownが返る（getFolders） | 異常系 | getFolders() | ✅ |
| 14 | フォルダを作成した場合、ローカル・リモート双方にsynced状態で保存される | 正常系 | createFolder() | ✅ |
| 15 | リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る（createFolder） | 異常系 | createFolder() / _mapException() | ✅ |
| 16 | リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る（createFolder） | 異常系 | createFolder() / _mapException() | ✅ |
| 17 | ローカル書き込みで想定外の例外が発生した場合、Failure.unknownが返る（createFolder） | 異常系 | createFolder() | ✅ |
| 18 | (オフライン)フォルダを作成した場合、ローカルにpending状態で保存されsync_queueにcreate登録される | 正常系 | createFolder() | ✅ |
| 19 | 既存フォルダを更新した場合、createdAtとparentFolderIdは維持されnameとupdatedAtが更新される | 正常系 | updateFolder() | ✅ |
| 20 | 存在しないフォルダIDを指定した場合、createdAtに現在時刻が使われparentFolderIdはnullになる | 境界値 | updateFolder() | ✅ |
| 21 | リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る（updateFolder） | 異常系 | updateFolder() / _mapException() | ✅ |
| 22 | リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る（updateFolder） | 異常系 | updateFolder() / _mapException() | ✅ |
| 23 | ローカル更新で想定外の例外が発生した場合、Failure.unknownが返る（updateFolder） | 異常系 | updateFolder() | ✅ |
| 24 | (オフライン)フォルダを更新した場合、ローカルがpending状態で更新されsync_queueにupdate登録される | 正常系 | updateFolder() | ✅ |

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

### テストケース11: 親フォルダIDを指定した場合、その配下のフォルダ一覧がローカルDBから取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: getFolders()
- **入力条件**: `root`配下に`child-1`・`child-2`、`root`とは無関係な`other-root`が存在。`parentFolderId: 'root'`を指定。
- **期待値**: `Right`で`child-1`・`child-2`のみを含むフォルダ一覧が返る。

### テストケース12: 該当するフォルダが存在しない場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: getFolders()
- **入力条件**: フォルダが1件も存在しない状態で`parentFolderId`を指定せずに呼び出す。
- **期待値**: `Right([])`が返る。

### テストケース13: ローカルDBアクセスで例外が発生した場合、Failure.unknownが返る（getFolders）
- **カテゴリ**: 異常系
- **対象メソッド**: getFolders()
- **入力条件**: `folders`テーブルを`DROP TABLE`で破壊してから呼び出す。
- **期待値**: `Left(UnknownFailure)`が返る。

### テストケース14: フォルダを作成した場合、ローカル・リモート双方にsynced状態で保存される
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()
- **入力条件**: オンライン状態。`name`・`parentFolderId`を指定して作成。
- **期待値**: 作成された`Folder`の`createdAt == updatedAt`。ローカルDBに保存され、`FakeFirestoreDataSource.writtenFolders`に1件記録される。

### テストケース15: リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る（createFolder）
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder() / _mapException()
- **入力条件**: `fakeRemote.exceptionToThrow`に`code: 'unavailable'`の`FirebaseException`を設定。
- **期待値**: `Left(Failure.network())`が返る。

### テストケース16: リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る（createFolder）
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder() / _mapException()
- **入力条件**: `fakeRemote.exceptionToThrow`に`code: 'permission-denied', message: 'denied'`の`FirebaseException`を設定。
- **期待値**: `Left(Failure.unknown('denied'))`が返る。

### テストケース17: ローカル書き込みで想定外の例外が発生した場合、Failure.unknownが返る（createFolder）
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder()
- **入力条件**: `folders`テーブルを`DROP TABLE`で破壊してから呼び出す（オンライン状態）。
- **期待値**: `Left(UnknownFailure)`が返る。

### テストケース18: (オフライン)フォルダを作成した場合、ローカルにpending状態で保存されsync_queueにcreate登録される
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()(オフライン分岐)
- **入力条件**: `FakeConnectivityMonitor`をオフラインに設定して作成。
- **期待値**: ローカルDBに保存され、`sync_queue`に`table_name = 'folders', operation = 'create'`の行が1件登録される。リモートへの書き込みは行われない。

### テストケース19: 既存フォルダを更新した場合、createdAtとparentFolderIdは維持されnameとupdatedAtが更新される
- **カテゴリ**: 正常系
- **対象メソッド**: updateFolder()
- **入力条件**: `folder-1`が`parentFolderId: 'root', createdAt: 2023-05-01`で既存。オンライン状態で`name`を更新。
- **期待値**: `parentFolderId`・`createdAt`は既存値のまま、`name`が更新され`updatedAt`が`createdAt`より後になる。リモートにも書き込まれる。

### テストケース20: 存在しないフォルダIDを指定した場合、createdAtに現在時刻が使われparentFolderIdはnullになる
- **カテゴリ**: 境界値
- **対象メソッド**: updateFolder()
- **入力条件**: ローカルに存在しない`folderId`を指定して更新（`existing`がnullになる境界）。
- **期待値**: `parentFolderId`が`null`、`createdAt == updatedAt`となる。

### テストケース21: リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る（updateFolder）
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder() / _mapException()
- **入力条件**: `fakeRemote.exceptionToThrow`に`code: 'network-request-failed'`の`FirebaseException`を設定。
- **期待値**: `Left(Failure.network())`が返る。

### テストケース22: リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る（updateFolder）
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder() / _mapException()
- **入力条件**: `fakeRemote.exceptionToThrow`に`code: 'permission-denied', message: 'denied'`の`FirebaseException`を設定。
- **期待値**: `Left(Failure.unknown('denied'))`が返る。

### テストケース23: ローカル更新で想定外の例外が発生した場合、Failure.unknownが返る（updateFolder）
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **入力条件**: `folders`テーブルを`DROP TABLE`で破壊してから呼び出す（オンライン状態）。
- **期待値**: `Left(UnknownFailure)`が返る。

### テストケース24: (オフライン)フォルダを更新した場合、ローカルがpending状態で更新されsync_queueにupdate登録される
- **カテゴリ**: 正常系
- **対象メソッド**: updateFolder()(オフライン分岐)
- **入力条件**: `FakeConnectivityMonitor`をオフラインに設定して`folder-1`の`name`を更新。
- **期待値**: ローカルDBの`name`が更新され、`sync_queue`に`table_name = 'folders', operation = 'update'`の行が1件登録される。リモートへの書き込みは行われない。

## 対象外

- L259：`deleteFolder()` の `catch (e) => Failure.unknown(...)` 防御的フォールバック。
  FirebaseException 以外の例外が到達する経路は実際には存在せず、同一構造の分岐は
  他メソッドのケースで網羅済みのため対象外とする。

## 補足: レビュー中に発見・修正した実装バグ

テスト作成の過程で、`deleteFolder()`のオフライン分岐に、`db.transaction((txn) async { ... })`の
コールバック内部から`_wordLocal.findByFolderId` / `_testResultLocal.findByUserId`
(いずれも`_dbHelper.database`経由でトランザクション**外**のDB接続を使う)を直接呼び出しており、
進行中のトランザクションのロックと競合してsqfliteが確実にデッドロックするバグが見つかった。

`lib/infrastructure/repositories/folder_repository_impl.dart`の実装を、削除対象の
word/testResultのIDを`db.transaction()`を開始する**前**に収集し、トランザクション内では
`txn.delete`と`syncQueue.enqueueInTransaction`のみを行うように修正済み。上記テストケース8〜10は
この修正後の正しい挙動を検証している。
