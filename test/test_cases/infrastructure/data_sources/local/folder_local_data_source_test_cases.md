# folder_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/folder_local_data_source.dart |
| クラス名 | FolderLocalDataSource |
| テスト対象メソッド | insert() / findById() / update() / delete() / findByUserId() / upsert() |

## 実行環境について

`sqflite_common_ffi` を用いて実際の SQLite エンジン（テスト専用の一時ディレクトリ）に対して
CRUD操作を行い、Dart Pure Testとして検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | フォルダをinsertした場合、findByIdでDateTimeがISO8601往復して取得できる | 正常系 | insert() / findById() | ✅ |
| 2 | 存在しないIDを指定した場合、findByIdはnullを返す | 異常系 | findById() | ✅ |
| 3 | 既存フォルダを更新した場合、name等の変更内容が反映される | 正常系 | update() | ✅ |
| 4 | 存在しないIDを指定して更新しても例外が発生せず正常終了する | 異常系 | update() | ✅ |
| 5 | 存在するフォルダを削除した場合、findByIdでnullになる | 正常系 | delete() | ✅ |
| 6 | parentFolderIdを指定しない場合、ルート直下(NULL)のフォルダのみ取得できる | 正常系 | findByUserId() | ✅ |
| 7 | parentFolderIdを指定した場合、その子フォルダのみ取得できる | 正常系 | findByUserId() | ✅ |
| 8 | 存在しないIDでupsertした場合、新規レコードとして挿入される | 正常系 | upsert() | ✅ |
| 9 | 既存IDでupsertした場合、レコードが置き換えられる（重複せず1件のまま） | 正常系 | upsert() | ✅ |

## テストケース詳細

### テストケース1: フォルダをinsertした場合、findByIdでDateTimeがISO8601往復して取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: insert() / findById()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: `createdAt`/`updatedAt`に分・秒を含む具体的な`DateTime`を設定したフォルダをinsertする。
- **操作手順**: `insert()`実行後、`findById('folder-1')`を呼ぶ。
- **期待結果**: 取得結果が`null`でなく、`createdAt`/`updatedAt`がinsert時のDateTimeと一致する（ISO8601文字列変換の往復が壊れていない）。

### テストケース2: 存在しないIDを指定した場合、findByIdはnullを返す
- **カテゴリ**: 異常系
- **対象メソッド**: findById()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: 存在しないID`not-exist`。
- **操作手順**: `findById('not-exist')`を呼ぶ。
- **期待結果**: `null`が返る。

### テストケース3: 既存フォルダを更新した場合、name等の変更内容が反映される
- **カテゴリ**: 正常系
- **対象メソッド**: update()
- **事前条件**: `folder-1`（name: 旧名）をinsert済み。
- **入力値・テスト条件**: 同じIDで`name`を新名、`updatedAt`を変更したFolderで`update()`を呼ぶ。
- **操作手順**: `update()`実行後`findById()`で再取得する。
- **期待結果**: `name`が新名になり、`updatedAt`も更新後の値になる。

### テストケース4: 存在しないIDを指定して更新しても例外が発生せず正常終了する
- **カテゴリ**: 異常系
- **対象メソッド**: update()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: 存在しないID`not-exist`のFolderで`update()`を呼ぶ。
- **操作手順**: `update()`のFutureを`completes`マッチャで検証する。
- **期待結果**: 例外を投げずに正常完了する（`WHERE id = ?`が0件ヒットするだけで例外にはならない）。

### テストケース5: 存在するフォルダを削除した場合、findByIdでnullになる
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: `folder-1`をinsert済み。
- **入力値・テスト条件**: `delete('folder-1')`。
- **操作手順**: `delete()`実行後`findById()`で確認する。
- **期待結果**: `null`が返る。

### テストケース6: parentFolderIdを指定しない場合、ルート直下(NULL)のフォルダのみ取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findByUserId()
- **事前条件**: ルート直下の`folder-1`と、`folder-1`を親に持つ`folder-2`をinsert。
- **入力値・テスト条件**: `findByUserId(userId)`（`parentFolderId`省略）。
- **操作手順**: 結果のIDリストを検証する。
- **期待結果**: `folder-1`のみが返る（`parentFolderId IS NULL`分岐）。

### テストケース7: parentFolderIdを指定した場合、その子フォルダのみ取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findByUserId()
- **事前条件**: `folder-1`配下に自ユーザーの`folder-2`と他ユーザーの`folder-3`をinsert。
- **入力値・テスト条件**: `findByUserId(userId, parentFolderId: 'folder-1')`。
- **操作手順**: 結果のIDリストを検証する。
- **期待結果**: 自ユーザーかつ`parentFolderId = 'folder-1'`の`folder-2`のみが返る。

### テストケース8: 存在しないIDでupsertした場合、新規レコードとして挿入される
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: 未登録の`folder-1`で`upsert()`を呼ぶ。
- **操作手順**: `upsert()`実行後`findById()`で確認する。
- **期待結果**: 新規レコードとして取得できる。

### テストケース9: 既存IDでupsertした場合、レコードが置き換えられる（重複せず1件のまま）
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: `folder-1`（name: 旧名）をinsert済み。
- **入力値・テスト条件**: 同じIDで`name`と`updatedAt`を変更した内容で`upsert()`を呼ぶ。
- **操作手順**: `upsert()`実行後`findByUserId()`で全件取得する。
- **期待結果**: レコード数は1件のまま、内容が新しい値に置き換わっている（`ConflictAlgorithm.replace`の確認）。
