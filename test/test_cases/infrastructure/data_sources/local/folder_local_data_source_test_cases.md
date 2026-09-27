# folder_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/folder_local_data_source.dart |
| クラス名 | FolderLocalDataSource |
| テスト対象メソッド | insert() / findById() / update() / delete() / findByUserId() / upsert() / findActive() / findActiveChildIds() / save() / markDeleted() |

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
| 10 | insertした場合、DBに保存されるcreatedAt/updatedAtがUTCのISO8601文字列(末尾Z)になる | 正常系 | insert() | ✅ |
| 11 | Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる | 境界値 | findById() | ✅ |
| 12 | deletedAtが設定されたフォルダを指定した場合、findByIdは削除済みでも取得できる | 正常系 | findById() | ✅ |
| 13 | deletedAtが設定されたフォルダが存在する場合、findByUserIdの結果に含まれない | 正常系 | findByUserId() | ✅ |
| 14 | 自ユーザーの未削除のフォルダを指定した場合、そのフォルダが取得できる | 正常系 | findActive() | ✅ |
| 15 | 削除済みのフォルダを指定した場合、findActiveはnullを返す | 異常系 | findActive() | ✅ |
| 16 | 他ユーザーのフォルダを指定した場合、findActiveはnullを返す | 異常系 | findActive() | ✅ |
| 17 | 未削除の子フォルダのみが存在する場合、それらのidが取得できる | 正常系 | findActiveChildIds() | ✅ |
| 18 | 他ユーザーの子フォルダが存在する場合、そのidは含まれない | 異常系 | findActiveChildIds() | ✅ |
| 19 | 未登録のフォルダをsaveした場合、新規レコードとして挿入される | 正常系 | save() | ✅ |
| 20 | 既存IDのフォルダをsaveした場合、レコードが置き換えられる（重複せず1件のまま） | 正常系 | save() | ✅ |
| 21 | 存在するフォルダをmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる | 正常系 | markDeleted() | ✅ |

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

### テストケース10: insertした場合、DBに保存されるcreatedAt/updatedAtがUTCのISO8601文字列(末尾Z)になる
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: `createdAt`/`updatedAt`に具体的な`DateTime`（ローカル時刻扱い）を設定したフォルダ。
- **操作手順**: `insert()`実行後、DBの生の行を直接`query()`して`createdAt`/`updatedAt`列を確認する。
- **期待結果**: 両列とも末尾が`Z`（UTCのISO8601文字列）で終わる。

### テストケース11: Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる
- **カテゴリ**: 境界値
- **対象メソッド**: findById()
- **事前条件**: `folder-1`をinsert済み。
- **入力値・テスト条件**: `createdAt`列を、末尾`Z`の無いバージョン1形式のISO8601文字列（`DateTime.toIso8601String()`のローカル表現）に直接書き換える。
- **操作手順**: `findById('folder-1')`を呼ぶ。
- **期待結果**: 取得した`createdAt`が、書き換えに使った`DateTime`（端末のタイムゾーンの時刻として解釈）と一致する。

### テストケース12: deletedAtが設定されたフォルダを指定した場合、findByIdは削除済みでも取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findById()
- **事前条件**: `folder-1`をinsert後、`markDeleted()`で論理削除済み。
- **入力値・テスト条件**: 削除済みの`folder-1`。
- **操作手順**: `findById('folder-1')`を呼ぶ。
- **期待結果**: `null`ではなく、削除済みのフォルダが取得できる。

### テストケース13: deletedAtが設定されたフォルダが存在する場合、findByUserIdの結果に含まれない
- **カテゴリ**: 正常系
- **対象メソッド**: findByUserId()
- **事前条件**: `folder-1`・`folder-2`をinsert後、`folder-1`のみ`markDeleted()`で論理削除済み。
- **入力値・テスト条件**: `findByUserId(userId)`。
- **操作手順**: 結果のIDリストを検証する。
- **期待結果**: `folder-2`のみが返り、削除済みの`folder-1`は含まれない。

### テストケース14: 自ユーザーの未削除のフォルダを指定した場合、そのフォルダが取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findActive()
- **事前条件**: 自ユーザーの`folder-1`をinsert済み。
- **入力値・テスト条件**: `findActive(db, 'folder-1', userId: userId)`。
- **操作手順**: 戻り値を検証する。
- **期待結果**: `folder-1`が取得できる。

### テストケース15: 削除済みのフォルダを指定した場合、findActiveはnullを返す
- **カテゴリ**: 異常系
- **対象メソッド**: findActive()
- **事前条件**: 自ユーザーの`folder-1`をinsert後、`markDeleted()`で論理削除済み。
- **入力値・テスト条件**: `findActive(db, 'folder-1', userId: userId)`。
- **操作手順**: 戻り値を検証する。
- **期待結果**: `null`が返る。

### テストケース16: 他ユーザーのフォルダを指定した場合、findActiveはnullを返す
- **カテゴリ**: 異常系
- **対象メソッド**: findActive()
- **事前条件**: `other-user`が所有する`folder-1`をinsert済み。
- **入力値・テスト条件**: `findActive(db, 'folder-1', userId: userId)`（自ユーザーとして問い合わせ）。
- **操作手順**: 戻り値を検証する。
- **期待結果**: `null`が返る。

### テストケース17: 未削除の子フォルダのみが存在する場合、それらのidが取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findActiveChildIds()
- **事前条件**: `folder-1`配下に自ユーザーの`folder-2`・`folder-3`をinsert後、`folder-3`のみ`markDeleted()`で論理削除済み。
- **入力値・テスト条件**: `findActiveChildIds(db, 'folder-1', userId: userId)`。
- **操作手順**: 戻り値のidリストを検証する。
- **期待結果**: 未削除の`folder-2`のidのみが返る。

### テストケース18: 他ユーザーの子フォルダが存在する場合、そのidは含まれない
- **カテゴリ**: 異常系
- **対象メソッド**: findActiveChildIds()
- **事前条件**: `folder-1`配下に`other-user`所有の`folder-2`をinsert済み。
- **入力値・テスト条件**: `findActiveChildIds(db, 'folder-1', userId: userId)`（自ユーザーとして問い合わせ）。
- **操作手順**: 戻り値のidリストを検証する。
- **期待結果**: 空リストが返る。

### テストケース19: 未登録のフォルダをsaveした場合、新規レコードとして挿入される
- **カテゴリ**: 正常系
- **対象メソッド**: save()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: 未登録の`folder-1`を`Database`インスタンスに対して`save()`する。
- **操作手順**: `save()`実行後`findById()`で確認する。
- **期待結果**: 新規レコードとして取得できる。

### テストケース20: 既存IDのフォルダをsaveした場合、レコードが置き換えられる（重複せず1件のまま）
- **カテゴリ**: 正常系
- **対象メソッド**: save()
- **事前条件**: `folder-1`（name: 旧名）を`save()`済み。
- **入力値・テスト条件**: 同じIDで`name`を新名にした内容で`save()`を呼ぶ。
- **操作手順**: `save()`実行後`findByUserId()`で全件取得する。
- **期待結果**: レコード数は1件のまま、`name`が新名に置き換わっている。

### テストケース21: 存在するフォルダをmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる
- **カテゴリ**: 正常系
- **対象メソッド**: markDeleted()
- **事前条件**: `folder-1`をinsert済み。
- **入力値・テスト条件**: `markDeleted(db, 'folder-1', deletedAt)`。
- **操作手順**: DBの生の行で`syncStatus`を確認し、`findById()`で`updatedAt`を確認する。
- **期待結果**: `syncStatus`が`pending`になり、`updatedAt`が指定した`deletedAt`と一致する。
