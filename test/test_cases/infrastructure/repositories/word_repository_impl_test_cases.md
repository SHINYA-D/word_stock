# word_repository_impl_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/word_repository_impl.dart |
| クラス名 | WordRepositoryImpl |
| テスト対象メソッド | getWords() / createWord() / updateWord() / deleteWord() / _mapException()（private、各メソッド経由で間接的に検証） |

## 実行環境について

`WordRepositoryImpl` は SQLite(sqflite)・Firestore・ネットワーク接続監視に依存するため、
以下の方針で Dart Pure Test として実行できるようにしている。

- **SQLite**: `sqflite_common_ffi` を dev_dependency として使用し、実際の SQLite エンジンを
  テスト専用の一時ディレクトリ上のファイルとして使用する
  (`WordLocalDataSource` / `SyncQueueDataSource` / `DatabaseHelper` は実クラスをそのまま使用)。
- **Firestore**: `FirestoreDataSource` を `implements` した手書きフェイク
  `test/helpers/fake_infrastructure.dart` の `FakeFirestoreDataSource` を使用し、
  実際の Firebase 通信は行わない。呼び出し内容を記録し検証する。
- **ネットワーク接続**: `ConnectivityMonitor` を `implements` した
  `FakeConnectivityMonitor` でオンライン/オフラインを固定する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | フォルダに単語が存在する場合、ローカルDBから単語一覧が取得できる | 正常系 | getWords() | ✅ |
| 2 | フォルダに単語が存在しない場合、空リストが返る | 境界値 | getWords() | ✅ |
| 3 | ローカルDBアクセスで例外が発生した場合、Failure.unknownが返る | 異常系 | getWords() | ✅ |
| 4 | 単語を作成した場合、ローカル・リモート双方に synced 状態で保存される | 正常系 | createWord()（オンライン） | ✅ |
| 5 | リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る | 異常系 | createWord()（オンライン） / _mapException() | ✅ |
| 6 | リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る | 異常系 | createWord()（オンライン） / _mapException() | ✅ |
| 7 | ローカル書き込みで想定外の例外が発生した場合、Failure.unknownが返る | 異常系 | createWord()（オンライン） | ✅ |
| 8 | 単語を作成した場合、ローカルにpending状態で保存されsync_queueにcreate登録される | 正常系 | createWord()（オフライン） | ✅ |
| 9 | 既存の単語を更新した場合、createdAtは維持されfrontとbackが更新される | 正常系 | updateWord()（オンライン） | ✅ |
| 10 | 存在しない単語IDを指定した場合、createdAtに現在時刻が使われ更新処理は継続される | 境界値 | updateWord()（オンライン） | ✅ |
| 11 | リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る | 異常系 | updateWord()（オンライン） | ✅ |
| 12 | 単語を更新した場合、ローカルがpending状態で更新されsync_queueにupdate登録される | 正常系 | updateWord()（オフライン） | ✅ |
| 13 | 単語を削除した場合、ローカル・リモート双方から削除される | 正常系 | deleteWord()（オンライン） | ✅ |
| 14 | リモート削除でFirebaseExceptionが発生した場合、Failure.networkが返る | 異常系 | deleteWord()（オンライン） | ✅ |
| 15 | 単語を削除した場合、ローカルから削除されsync_queueにdelete登録される | 正常系 | deleteWord()（オフライン） | ✅ |

## テストケース詳細

### テストケース1: フォルダに単語が存在する場合、ローカルDBから単語一覧が取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: getWords()
- **入力条件**: `folder-1` に単語2件を事前登録。
- **期待値**: `Right`が返り、取得した単語IDの集合が事前登録した2件と一致する。

### テストケース2: フォルダに単語が存在しない場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: getWords()
- **入力条件**: 単語を1件も登録していない状態。
- **期待値**: `Right([])`が返る。

### テストケース3: ローカルDBアクセスで例外が発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: getWords()
- **入力条件**: `DROP TABLE words` でテーブルを破壊し、`findByFolderId`のクエリを失敗させる（テスト後にテーブルを再作成し後続テストへの影響を防ぐ）。
- **期待値**: `Left(UnknownFailure)`が返る。

### テストケース4: 単語を作成した場合、ローカル・リモート双方に synced 状態で保存される
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()（オンライン）
- **入力条件**: `FakeConnectivityMonitor`がオンライン。front/backを指定。
- **期待値**: `Right(Word)`が返り、`createdAt == updatedAt`。ローカルDBに1件保存され、`FakeFirestoreDataSource.writtenWords`に1件記録される。

### テストケース5: リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()（オンライン） / _mapException()
- **入力条件**: `fakeRemote.exceptionToThrow`に`code: 'unavailable'`のFirebaseExceptionを設定。
- **期待値**: `Left(Failure.network())`が返る。

### テストケース6: リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()（オンライン） / _mapException()
- **入力条件**: `fakeRemote.exceptionToThrow`に`code: 'permission-denied', message: 'denied'`のFirebaseExceptionを設定。
- **期待値**: `Left(Failure.unknown('denied'))`が返る。

### テストケース7: ローカル書き込みで想定外の例外が発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()（オンライン）
- **入力条件**: `DROP TABLE words` でテーブルを破壊し、`_local.insert`のクエリを失敗させる（テスト後にテーブルを再作成し後続テストへの影響を防ぐ）。
- **期待値**: `Left(UnknownFailure)`が返る。

### テストケース8: 単語を作成した場合、ローカルにpending状態で保存されsync_queueにcreate登録される
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()（オフライン）
- **入力条件**: `FakeConnectivityMonitor`をオフラインに設定。
- **期待値**: `Right(Word)`が返り、ローカルDBに1件保存され、`sync_queue`に`table_name='words', operation='create'`の行が1件登録される。リモート書き込みは呼ばれない。

### テストケース9: 既存の単語を更新した場合、createdAtは維持されfrontとbackが更新される
- **カテゴリ**: 正常系
- **対象メソッド**: updateWord()（オンライン）
- **入力条件**: `createdAt = 2023-05-01`の単語`word-1`を事前登録。front/backを新しい値で更新。
- **期待値**: 返る`Word.createdAt`は元の値のまま、`front`/`back`が更新され、`updatedAt`は`createdAt`より新しい。リモートにも書き込まれる。

### テストケース10: 存在しない単語IDを指定した場合、createdAtに現在時刻が使われ更新処理は継続される
- **カテゴリ**: 境界値
- **対象メソッド**: updateWord()（オンライン）
- **入力条件**: ローカルDBに存在しない`wordId`を指定。
- **期待値**: `existing == null`のため`createdAt`に現在時刻が使われ、`createdAt == updatedAt`となる`Right(Word)`が返る（例外にならず処理が継続される）。

### テストケース11: リモート書き込みでFirebaseExceptionが発生した場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()（オンライン）
- **入力条件**: 単語`word-1`を事前登録。`fakeRemote.exceptionToThrow`に`code: 'network-request-failed'`のFirebaseExceptionを設定。
- **期待値**: `Left(Failure.network())`が返る。

### テストケース12: 単語を更新した場合、ローカルがpending状態で更新されsync_queueにupdate登録される
- **カテゴリ**: 正常系
- **対象メソッド**: updateWord()（オフライン）
- **入力条件**: 単語`word-1`を事前登録。オフライン状態。
- **期待値**: ローカルDBの`front`が更新され、`sync_queue`に`operation='update'`の行が1件登録される。リモート書き込みは呼ばれない。

### テストケース13: 単語を削除した場合、ローカル・リモート双方から削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteWord()（オンライン）
- **入力条件**: 単語`word-1`を事前登録。オンライン状態。
- **期待値**: `Right(unit)`が返り、ローカルDBから削除され、`deletedWords`に記録される。

### テストケース14: リモート削除でFirebaseExceptionが発生した場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()（オンライン）
- **入力条件**: 単語`word-1`を事前登録。`fakeRemote.exceptionToThrow`に`code: 'unavailable'`のFirebaseExceptionを設定。
- **期待値**: `Left(Failure.network())`が返る。

### テストケース15: 単語を削除した場合、ローカルから削除されsync_queueにdelete登録される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteWord()（オフライン）
- **入力条件**: 単語`word-1`を事前登録。オフライン状態。
- **期待値**: ローカルDBから削除され、`sync_queue`に`operation='delete'`の行が1件登録される。リモート削除は呼ばれない。

## 対象外

- L166, L203：`catch (e) => Failure.unknown(...)` 防御的フォールバック。FirebaseException 以外の
  例外が到達する経路は実際には存在せず、同一構造の分岐は他メソッドのケースで網羅済みのため対象外とする。
