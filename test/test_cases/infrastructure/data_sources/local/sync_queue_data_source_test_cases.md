# sync_queue_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/sync_queue_data_source.dart |
| クラス名 | SyncQueueDataSource |
| テスト対象メソッド | enqueue() / enqueueInTransaction() / getByUser() / getAll() / delete() / deleteForRecord() / hasItemsForRecord() / count() / countByUser() |

## 実行環境について

`SyncQueueDataSource` は SQLite(sqflite) の `sync_queue` テーブルにのみ依存するため、
`sqflite_common_ffi` を使いテスト専用の一時ディレクトリ上の実 SQLite で検証する
（`DatabaseHelper` は実クラスをそのまま使用）。

このファイル単体が担当する仕様書の仕様 ID は無い（`sync_queue` の振る舞いは
`docs/detailed_design/online_offline/online_offline.md` の SyncService・Repository 側の
仕様 ID で確認済みのため、この項目書はコードから設計している）。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | パラメータを指定してenqueueした場合、operation・tableName・recordId・userId・parentId・created_atがそのままキューに保存される | 正常系 | enqueue() | ✅ |
| 2 | parentIdを指定しない場合、nullで保存される | 境界値 | enqueue() | ✅ |
| 3 | 複数回enqueueした場合、件数分レコードが積み上がる | 正常系 | enqueue() | ✅ |
| 4 | 同一エンティティ（同じrecordId）に対して複数回enqueueした場合、重複して両方登録される | 正常系 | enqueue() | ✅ |
| 5 | データ書き込みと同一トランザクション内で成功した場合、両方コミットされる | 正常系 | enqueueInTransaction() | ✅ |
| 6 | トランザクション途中で例外が発生してロールバックした場合、データ書き込みとキュー登録の両方が取り消される | 異常系 | enqueueInTransaction() | ✅ |
| 7 | 複数件登録されている場合、積んだ順（id昇順）でそのユーザーの項目だけが取得できる | 正常系 | getByUser() | ✅ |
| 8 | 該当ユーザーの項目が無い場合、空リストが返る | 境界値 | getByUser() | ✅ |
| 9 | 取得したcreatedAtがUTCのDateTimeとして返る | 正常系 | getByUser() | ✅ |
| 10 | キューが空の場合、空リストが返る | 境界値 | getAll() | ✅ |
| 11 | 複数件登録されている場合、積んだ順（id昇順）で全ユーザー分取得できる | 正常系 | getAll() | ✅ |
| 12 | 存在するidを削除した場合、キューから取り除かれる | 正常系 | delete() | ✅ |
| 13 | 複数件ある場合、指定したidのレコードのみ削除される | 正常系 | delete() | ✅ |
| 14 | 存在しないidを削除しても例外が発生せず正常終了する | 境界値 | delete() | ✅ |
| 15 | トランザクションを渡して削除した場合、そのトランザクション内で削除される | 正常系 | delete() | ✅ |
| 16 | 同じテーブル・レコードを指す項目が複数ある場合、まとめて削除される | 正常系 | deleteForRecord() | ✅ |
| 17 | 該当するレコードの項目が無い場合、他の項目は削除されない | 境界値 | deleteForRecord() | ✅ |
| 18 | 指定したテーブル・レコードの項目が残っている場合、trueが返る | 正常系 | hasItemsForRecord() | ✅ |
| 19 | 指定したテーブル・レコードの項目が無い場合、falseが返る | 境界値 | hasItemsForRecord() | ✅ |
| 20 | キューが空の場合、countは0が返る | 境界値 | count() | ✅ |
| 21 | 複数件登録されている場合、countはその件数が返る | 正常系 | count() | ✅ |
| 22 | countByUserは他ユーザーの項目を含まず、指定したユーザーの件数だけが返る | 正常系 | countByUser() | ✅ |
| 23 | 該当ユーザーの項目が無い場合、countByUserは0が返る | 境界値 | countByUser() | ✅ |

## テストケース詳細

### テストケース1: パラメータを指定してenqueueした場合、operation・tableName・recordId・userId・parentId・created_atがそのままキューに保存される
- **カテゴリ**: 正常系
- **対象メソッド**: enqueue()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: operation='upsert', tableName='folders', recordId='folder-1', userId='user-1', parentId='parent-1'
- **操作手順**: `dataSource.enqueue(...)` を呼ぶ
- **期待結果**: `sync_queue` に1件挿入され、各列に指定した値がそのまま入り、`created_at` が非null

### テストケース2: parentIdを指定しない場合、nullで保存される
- **カテゴリ**: 境界値
- **対象メソッド**: enqueue()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: parentIdを渡さずにenqueueする
- **操作手順**: `dataSource.enqueue(operation: 'delete', tableName: 'words', recordId: 'word-1', userId: 'user-1')` を呼ぶ
- **期待結果**: `parent_id` 列がnullで保存される

### テストケース3: 複数回enqueueした場合、件数分レコードが積み上がる
- **カテゴリ**: 正常系
- **対象メソッド**: enqueue()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: 異なるrecordIdで2回enqueueする
- **操作手順**: `enqueue` を2回呼んだあと `count()` を呼ぶ
- **期待結果**: `count()` が2を返す

### テストケース4: 同一エンティティ（同じrecordId）に対して複数回enqueueした場合、重複して両方登録される
- **カテゴリ**: 正常系
- **対象メソッド**: enqueue()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: 同じrecordId='folder-1'で2回enqueueする
- **操作手順**: `enqueue` を同じrecordIdで2回呼ぶ
- **期待結果**: `sync_queue` に'folder-1'を指す行が2件残る（重複除去されない）

### テストケース5: データ書き込みと同一トランザクション内で成功した場合、両方コミットされる
- **カテゴリ**: 正常系
- **対象メソッド**: enqueueInTransaction()
- **事前条件**: `folders`・`sync_queue` テーブルが空。
- **入力値・テスト条件**: `db.transaction` 内で `folders` へ1件insertし、同じtxnで`enqueueInTransaction`を呼ぶ
- **操作手順**: トランザクションを正常終了させる
- **期待結果**: `folders` に1件、`sync_queue` に1件（`record_id = 'folder-1'`）が両方コミットされる

### テストケース6: トランザクション途中で例外が発生してロールバックした場合、データ書き込みとキュー登録の両方が取り消される
- **カテゴリ**: 異常系
- **対象メソッド**: enqueueInTransaction()
- **事前条件**: `folders`・`sync_queue` テーブルが空。
- **入力値・テスト条件**: `folders`へのinsertと`enqueueInTransaction`の後に例外をthrowする
- **操作手順**: `db.transaction(...)` の呼び出しが例外をthrowすることを確認する
- **期待結果**: `folders`・`sync_queue` とも空のまま（ロールバックされる）

### テストケース7: 複数件登録されている場合、積んだ順（id昇順）でそのユーザーの項目だけが取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: getByUser()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: user-1の項目2件（folder-1, word-1（parentId='folder-1'））と、user-2の項目1件をこの順でenqueueする
- **操作手順**: `dataSource.getByUser('user-1')` を呼ぶ
- **期待結果**: 戻り値は積んだ順（id昇順）で `[folder-1, word-1]` の2件のみ。user-2の項目は含まれない。各項目の`operation`・`tableName`・`parentId`もenqueue時の値と一致する

### テストケース8: 該当ユーザーの項目が無い場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: getByUser()
- **事前条件**: user-2の項目のみenqueue済み。
- **入力値・テスト条件**: user-1を指定して取得する
- **操作手順**: `dataSource.getByUser('user-1')` を呼ぶ
- **期待結果**: 空リストが返る

### テストケース9: 取得したcreatedAtがUTCのDateTimeとして返る
- **カテゴリ**: 正常系
- **対象メソッド**: getByUser()
- **事前条件**: user-1の項目を1件enqueue済み。
- **入力値・テスト条件**: なし
- **操作手順**: `dataSource.getByUser('user-1')` を呼び、先頭要素の`createdAt`を確認する
- **期待結果**: `createdAt.isUtc` が true

### テストケース10: キューが空の場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: getAll()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: なし
- **操作手順**: `dataSource.getAll()` を呼ぶ
- **期待結果**: 空リストが返る

### テストケース11: 複数件登録されている場合、積んだ順（id昇順）で全ユーザー分取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: getAll()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: user-1、user-2の項目をこの順でenqueueする
- **操作手順**: `dataSource.getAll()` を呼ぶ
- **期待結果**: `record_id` が積んだ順（`['folder-1', 'folder-2']`）で返る（ユーザーで絞られない）

### テストケース12: 存在するidを削除した場合、キューから取り除かれる
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: 項目を1件enqueue済み。
- **入力値・テスト条件**: 取得したidを指定する
- **操作手順**: `dataSource.delete(id)` を呼ぶ
- **期待結果**: `getAll()` が空リストを返す

### テストケース13: 複数件ある場合、指定したidのレコードのみ削除される
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: 項目を2件enqueue済み。
- **入力値・テスト条件**: 先頭の項目のidを指定する
- **操作手順**: `dataSource.delete(firstId)` を呼ぶ
- **期待結果**: 残りの項目（`folder-2`）のみが`getAll()`に残る

### テストケース14: 存在しないidを削除しても例外が発生せず正常終了する
- **カテゴリ**: 境界値
- **対象メソッド**: delete()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: 存在しないid=9999を指定する
- **操作手順**: `dataSource.delete(9999)` を呼ぶ
- **期待結果**: 例外を投げず正常終了する（`completes`）

### テストケース15: トランザクションを渡して削除した場合、そのトランザクション内で削除される
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: 項目を1件enqueue済み。
- **入力値・テスト条件**: `db.transaction` 内で`delete(id, txn)`を呼ぶ
- **操作手順**: トランザクション経由で`delete`を呼ぶ
- **期待結果**: コミット後 `getAll()` が空リストを返す

### テストケース16: 同じテーブル・レコードを指す項目が複数ある場合、まとめて削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteForRecord()
- **事前条件**: `folders`/`folder-1` を指す項目2件、`folders`/`folder-2` を指す項目1件をenqueue済み。
- **入力値・テスト条件**: tableName='folders', recordId='folder-1'
- **操作手順**: トランザクション内で `dataSource.deleteForRecord(txn, 'folders', 'folder-1')` を呼ぶ
- **期待結果**: `folder-1` を指す2件が削除され、`folder-2` を指す項目のみ残る

### テストケース17: 該当するレコードの項目が無い場合、他の項目は削除されない
- **カテゴリ**: 境界値
- **対象メソッド**: deleteForRecord()
- **事前条件**: `folders`/`folder-1` を指す項目を1件enqueue済み。
- **入力値・テスト条件**: tableName='folders', recordId='not-exist'（存在しないレコード）
- **操作手順**: トランザクション内で `dataSource.deleteForRecord(txn, 'folders', 'not-exist')` を呼ぶ
- **期待結果**: 件数が変わらず1件のまま

### テストケース18: 指定したテーブル・レコードの項目が残っている場合、trueが返る
- **カテゴリ**: 正常系
- **対象メソッド**: hasItemsForRecord()
- **事前条件**: `folders`/`folder-1` を指す項目を1件enqueue済み。
- **入力値・テスト条件**: tableName='folders', recordId='folder-1'
- **操作手順**: トランザクション内で `dataSource.hasItemsForRecord(txn, 'folders', 'folder-1')` を呼ぶ
- **期待結果**: trueが返る

### テストケース19: 指定したテーブル・レコードの項目が無い場合、falseが返る
- **カテゴリ**: 境界値
- **対象メソッド**: hasItemsForRecord()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: tableName='folders', recordId='folder-1'
- **操作手順**: トランザクション内で `dataSource.hasItemsForRecord(txn, 'folders', 'folder-1')` を呼ぶ
- **期待結果**: falseが返る

### テストケース20: キューが空の場合、countは0が返る
- **カテゴリ**: 境界値
- **対象メソッド**: count()
- **事前条件**: `sync_queue` テーブルが空。
- **入力値・テスト条件**: なし
- **操作手順**: `dataSource.count()` を呼ぶ
- **期待結果**: 0が返る

### テストケース21: 複数件登録されている場合、countはその件数が返る
- **カテゴリ**: 正常系
- **対象メソッド**: count()
- **事前条件**: user-1・user-2の項目を1件ずつenqueue済み。
- **入力値・テスト条件**: なし
- **操作手順**: `dataSource.count()` を呼ぶ
- **期待結果**: 2が返る

### テストケース22: countByUserは他ユーザーの項目を含まず、指定したユーザーの件数だけが返る
- **カテゴリ**: 正常系
- **対象メソッド**: countByUser()
- **事前条件**: user-1の項目2件、user-2の項目1件をenqueue済み。
- **入力値・テスト条件**: userId='user-1'
- **操作手順**: `dataSource.countByUser('user-1')` を呼ぶ
- **期待結果**: 2が返る

### テストケース23: 該当ユーザーの項目が無い場合、countByUserは0が返る
- **カテゴリ**: 境界値
- **対象メソッド**: countByUser()
- **事前条件**: user-2の項目のみenqueue済み。
- **入力値・テスト条件**: userId='user-1'
- **操作手順**: `dataSource.countByUser('user-1')` を呼ぶ
- **期待結果**: 0が返る

## 対象外

なし（対象ファイルのカバレッジは100%）。
