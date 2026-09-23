# sync_queue_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/sync_queue_data_source.dart |
| クラス名 | SyncQueueDataSource |
| テスト対象メソッド | enqueue() / enqueueInTransaction() / getAll() / delete() / count() |

## 実行環境について

`SyncQueueDataSource` は SQLite(sqflite) にのみ依存するため、`sqflite_common_ffi` を使い
実際の SQLite エンジンをテスト専用の一時ディレクトリ上のファイルとして使用する
（`DatabaseHelper` は実クラスをそのまま使用）。他のテストファイルとの DB ファイルロック競合を
避けるため、このテストファイル専用に `Directory.systemTemp.createTemp()` でパスを分離している。

`enqueueInTransaction` については、`SyncQueueDataSource` 自体はトランザクションを開始しない
（呼び出し元が `db.transaction()` の中で使うAPI）ため、テスト内で `FolderTable` への書き込みと
組み合わせた実際のトランザクションを作り、コミット時・ロールバック時の両方の挙動を検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | payloadを指定した場合、JSON文字列としてpayload列に保存される | 正常系 | enqueue() | ✅ |
| 2 | parentId・payloadを指定しない場合、それぞれnullで保存される | 境界値 | enqueue() | ✅ |
| 3 | 複数回enqueueした場合、件数分レコードが積み上がる | 正常系 | enqueue() | ✅ |
| 4 | 同一エンティティ（同じrecordId）に対して複数回enqueueした場合、重複して両方登録される | 境界値 | enqueue() | ✅ |
| 5 | データ書き込みと同一トランザクション内で成功した場合、両方コミットされる | 正常系 | enqueueInTransaction() | ✅ |
| 6 | トランザクション途中で例外が発生してロールバックした場合、データ書き込みとキュー登録の両方が取り消される | 異常系 | enqueueInTransaction() | ✅ |
| 7 | キューが空の場合、空リストが返る | 境界値 | getAll() | ✅ |
| 8 | 複数件登録されている場合、created_atの古い順（登録順）に取得できる | 正常系 | getAll() | ✅ |
| 9 | 存在するidを削除した場合、キューから取り除かれる | 正常系 | delete() | ✅ |
| 10 | 複数件ある場合、指定したidのレコードのみ削除される | 正常系 | delete() | ✅ |
| 11 | 存在しないidを削除しても例外が発生せず正常終了する | 異常系 | delete() | ✅ |
| 12 | キューが空の場合、0が返る | 境界値 | count() | ✅ |
| 13 | 複数件登録されている場合、その件数が返る | 正常系 | count() | ✅ |

## テストケース詳細

### テストケース1: payloadを指定した場合、JSON文字列としてpayload列に保存される
- **カテゴリ**: 正常系
- **対象メソッド**: enqueue()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: operation='insert', tableName='folders', recordId='folder-1', parentId='parent-1', payload={'name': 'テストフォルダ'}
- **操作手順**: `enqueue()` を呼び出す
- **期待結果**: sync_queueに1件登録され、payload列がJSON文字列 `{"name":"テストフォルダ"}` として保存される。created_atも設定される

### テストケース2: parentId・payloadを指定しない場合、それぞれnullで保存される
- **カテゴリ**: 境界値
- **対象メソッド**: enqueue()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: operation='delete', tableName='words', recordId='word-1'（parentId, payload省略）
- **操作手順**: `enqueue()` を呼び出す
- **期待結果**: parent_id列・payload列がともにnullで保存される

### テストケース3: 複数回enqueueした場合、件数分レコードが積み上がる
- **カテゴリ**: 正常系
- **対象メソッド**: enqueue()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: 異なるrecordIdで2回enqueue
- **操作手順**: `enqueue()` を2回呼び出した後 `count()` を呼ぶ
- **期待結果**: `count()` が2を返す

### テストケース4: 同一エンティティ（同じrecordId）に対して複数回enqueueした場合、重複して両方登録される
- **カテゴリ**: 境界値
- **対象メソッド**: enqueue()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: 同じrecordId='folder-1'でoperation='update'を2回enqueue
- **操作手順**: `enqueue()` を2回呼び出す
- **期待結果**: record_idが'folder-1'のレコードが2件登録される（重複排除は行われない仕様）

### テストケース5: データ書き込みと同一トランザクション内で成功した場合、両方コミットされる
- **カテゴリ**: 正常系
- **対象メソッド**: enqueueInTransaction()
- **事前条件**: foldersテーブル・sync_queueテーブルが空
- **入力値・テスト条件**: `db.transaction()` 内で folders への insert と `enqueueInTransaction()` を実行
- **操作手順**: トランザクションを正常終了させる
- **期待結果**: foldersテーブルに1件、sync_queueテーブルに1件、それぞれコミットされて存在する

### テストケース6: トランザクション途中で例外が発生してロールバックした場合、データ書き込みとキュー登録の両方が取り消される
- **カテゴリ**: 異常系
- **対象メソッド**: enqueueInTransaction()
- **事前条件**: foldersテーブル・sync_queueテーブルが空
- **入力値・テスト条件**: `db.transaction()` 内で folders への insert → `enqueueInTransaction()` → 例外throw、の順で実行
- **操作手順**: `db.transaction()` の呼び出しが例外を投げることを確認する
- **期待結果**: foldersテーブル・sync_queueテーブルともに0件（両方ロールバックされる）

### テストケース7: キューが空の場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: getAll()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: なし
- **操作手順**: `getAll()` を呼び出す
- **期待結果**: 空リストが返る

### テストケース8: 複数件登録されている場合、created_atの古い順（登録順）に取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: getAll()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: folder-1, folder-2, folder-3 の順にenqueue
- **操作手順**: `getAll()` を呼び出す
- **期待結果**: record_idが `['folder-1', 'folder-2', 'folder-3']` の順で返る

### テストケース9: 存在するidを削除した場合、キューから取り除かれる
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: sync_queueに1件登録済み
- **入力値・テスト条件**: 登録済みレコードのid
- **操作手順**: `delete(id)` を呼び出し、`getAll()` で確認する
- **期待結果**: `getAll()` が空リストを返す

### テストケース10: 複数件ある場合、指定したidのレコードのみ削除される
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: sync_queueに2件登録済み（folder-1, folder-2）
- **入力値・テスト条件**: 1件目のid
- **操作手順**: `delete(firstId)` を呼び出す
- **期待結果**: folder-2のみが残る

### テストケース11: 存在しないidを削除しても例外が発生せず正常終了する
- **カテゴリ**: 異常系
- **対象メソッド**: delete()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: id=9999（存在しないid）
- **操作手順**: `delete(9999)` を呼び出す
- **期待結果**: 例外を投げずに正常終了する（`completes`）

### テストケース12: キューが空の場合、0が返る
- **カテゴリ**: 境界値
- **対象メソッド**: count()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: なし
- **操作手順**: `count()` を呼び出す
- **期待結果**: 0が返る

### テストケース13: 複数件登録されている場合、その件数が返る
- **カテゴリ**: 正常系
- **対象メソッド**: count()
- **事前条件**: sync_queueテーブルが空
- **入力値・テスト条件**: folder-1, folder-2 をenqueue
- **操作手順**: `count()` を呼び出す
- **期待結果**: 2が返る

## 対象外

なし（全行がテストで到達可能なため、対象外登録は不要と判断）
