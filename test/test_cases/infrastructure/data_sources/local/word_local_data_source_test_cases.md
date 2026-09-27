# word_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/word_local_data_source.dart |
| クラス名 | WordLocalDataSource |
| テスト対象メソッド | insert() / update() / delete() / findById() / findByFolderId() / upsert() / deleteByFolderId() / findActive() / findActiveIdsByFolder() / save() / markDeleted() |

## 実行環境について

`sqflite_common_ffi` を用いて実際の SQLite エンジン（テスト専用の一時ディレクトリ）に対して
CRUD操作を行い、Dart Pure Testとして検証する。DateTime ↔ String(ISO8601) の変換往復も検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 単語を挿入した場合、findByIdで同じ内容が取得できる | 正常系 | insert() | ✅ |
| 2 | createdAt/updatedAtがISO8601文字列で保存され、DateTimeとして往復変換される | 正常系 | insert() | ✅ |
| 3 | syncStatusを省略した場合、synced として保存される | 境界値 | insert() | ✅ |
| 4 | syncStatusを指定した場合、指定した値で保存される | 正常系 | insert() | ✅ |
| 5 | 同じIDで再度insertした場合、conflictAlgorithm.replaceにより上書きされる | 正常系 | insert() | ✅ |
| 6 | 既存レコードを更新した場合、findByIdで更新後の内容が取得できる | 正常系 | update() | ✅ |
| 7 | syncStatusを指定して更新した場合、指定した値で保存される | 正常系 | update() | ✅ |
| 8 | 存在しないIDを指定して更新しても例外が発生せず正常終了する | 異常系 | update() | ✅ |
| 9 | 存在するレコードを削除した場合、そのレコードが取得できなくなる | 正常系 | delete() | ✅ |
| 10 | 複数レコードが存在する場合、指定したIDのレコードのみが削除される | 正常系 | delete() | ✅ |
| 11 | 存在しないIDを指定して削除しても例外が発生せず正常終了する | 異常系 | delete() | ✅ |
| 12 | 存在するIDを指定した場合、該当する単語が取得できる | 正常系 | findById() | ✅ |
| 13 | 存在しないIDを指定した場合、nullが返る | 境界値 | findById() | ✅ |
| 14 | folderIdとuserIdの両方が一致するレコードのみ取得できる | 正常系 | findByFolderId() | ✅ |
| 15 | 該当レコードが0件の場合、空リストが返る | 境界値 | findByFolderId() | ✅ |
| 16 | 複数件存在する場合、createdAt昇順で返る | 正常系 | findByFolderId() | ✅ |
| 17 | 新規IDの場合、レコードが挿入される | 正常系 | upsert() | ✅ |
| 18 | 既存IDの場合、レコードが上書きされる | 正常系 | upsert() | ✅ |
| 19 | syncStatusを指定しない場合、synced として保存される | 境界値 | upsert() | ✅ |
| 20 | 指定したfolderIdのレコードが全て削除される | 正常系 | deleteByFolderId() | ✅ |
| 21 | 該当レコードが存在しない場合でも例外が発生せず正常終了する | 異常系 | deleteByFolderId() | ✅ |
| 22 | insertした場合、DBに保存されるcreatedAt/updatedAtがUTCのISO8601文字列(末尾Z)になる | 正常系 | insert() | ✅ |
| 23 | Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる | 境界値 | findById() | ✅ |
| 24 | deletedAtが設定された単語を指定した場合、findByIdは削除済みでも取得できる | 正常系 | findById() | ✅ |
| 25 | deletedAtが設定された単語が存在する場合、findByFolderIdの結果に含まれない | 正常系 | findByFolderId() | ✅ |
| 26 | 自ユーザーの未削除の単語を指定した場合、その単語が取得できる | 正常系 | findActive() | ✅ |
| 27 | 削除済みの単語を指定した場合、findActiveはnullを返す | 異常系 | findActive() | ✅ |
| 28 | 他ユーザーの単語を指定した場合、findActiveはnullを返す | 異常系 | findActive() | ✅ |
| 29 | 未削除の単語のみが存在する場合、それらのidが取得できる | 正常系 | findActiveIdsByFolder() | ✅ |
| 30 | 他ユーザーの単語が存在する場合、そのidは含まれない | 異常系 | findActiveIdsByFolder() | ✅ |
| 31 | 未登録の単語をsaveした場合、新規レコードとして挿入される | 正常系 | save() | ✅ |
| 32 | 既存IDの単語をsaveした場合、レコードが置き換えられる（重複せず1件のまま） | 正常系 | save() | ✅ |
| 33 | 存在する単語をmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる | 正常系 | markDeleted() | ✅ |

## テストケース詳細

### テストケース1: 単語を挿入した場合、findByIdで同じ内容が取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: `Word(id: 'word-1', front: 'front', back: 'back', ...)`
- **操作手順**: `insert(word, userId: userId, folderId: 'folder-1')` を呼び、`findById('word-1')` で取得
- **期待結果**: id/front/backが一致するWordが取得できる

### テストケース2: createdAt/updatedAtがISO8601文字列で保存され、DateTimeとして往復変換される
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: 秒単位まで指定したcreatedAt/updatedAt
- **操作手順**: insert後にfindByIdで取得
- **期待結果**: 取得したWordのcreatedAt/updatedAtが元のDateTimeと完全一致

### テストケース3: syncStatusを省略した場合、synced として保存される
- **カテゴリ**: 境界値
- **対象メソッド**: insert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: syncStatus引数を省略
- **操作手順**: insert後にDBを直接クエリしてsyncStatus列を確認
- **期待結果**: syncStatus列が'synced'

### テストケース4: syncStatusを指定した場合、指定した値で保存される
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: syncStatus: 'pending'
- **操作手順**: insert後にDBを直接クエリ
- **期待結果**: syncStatus列が'pending'

### テストケース5: 同じIDで再度insertした場合、conflictAlgorithm.replaceにより上書きされる
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: 'word-1'（front='old-front'）が既にinsert済み
- **入力値・テスト条件**: 同一idで front='new-front' を再insert
- **操作手順**: 2回目のinsert後にDBを直接クエリ
- **期待結果**: レコード数が1件のまま、frontが'new-front'に置き換わる

### テストケース6: 既存レコードを更新した場合、findByIdで更新後の内容が取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: update()
- **事前条件**: 'word-1'（front='old-front'）が既にinsert済み
- **入力値・テスト条件**: front='updated-front'
- **操作手順**: `update(word, ...)` を呼び、findByIdで取得
- **期待結果**: frontが'updated-front'

### テストケース7: syncStatusを指定して更新した場合、指定した値で保存される
- **カテゴリ**: 正常系
- **対象メソッド**: update()
- **事前条件**: 'word-1'がinsert済み（syncStatus='synced'）
- **入力値・テスト条件**: syncStatus: 'pending'を指定してupdate
- **操作手順**: update後にDBを直接クエリ
- **期待結果**: syncStatus列が'pending'

### テストケース8: 存在しないIDを指定して更新しても例外が発生せず正常終了する
- **カテゴリ**: 異常系
- **対象メソッド**: update()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: id='not-exist'
- **操作手順**: `update(word, ...)` を呼ぶ
- **期待結果**: 例外を投げず`Future`が正常完了する（`completes`）

### テストケース9: 存在するレコードを削除した場合、そのレコードが取得できなくなる
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: 'word-1'がinsert済み
- **入力値・テスト条件**: id='word-1'
- **操作手順**: `delete('word-1')` を呼び、findByIdで確認
- **期待結果**: findByIdがnullを返す

### テストケース10: 複数レコードが存在する場合、指定したIDのレコードのみが削除される
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **事前条件**: 'word-1'・'word-2'が同一folderにinsert済み
- **入力値・テスト条件**: id='word-1'
- **操作手順**: `delete('word-1')` を呼び、findByFolderIdで確認
- **期待結果**: 'word-2'のみが残る

### テストケース11: 存在しないIDを指定して削除しても例外が発生せず正常終了する
- **カテゴリ**: 異常系
- **対象メソッド**: delete()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: id='not-exist'
- **操作手順**: `delete('not-exist')` を呼ぶ
- **期待結果**: 例外を投げず`Future`が正常完了する（`completes`）

### テストケース12: 存在するIDを指定した場合、該当する単語が取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findById()
- **事前条件**: 'word-1'がinsert済み
- **入力値・テスト条件**: id='word-1'
- **操作手順**: `findById('word-1')` を呼ぶ
- **期待結果**: 該当するWordが返る

### テストケース13: 存在しないIDを指定した場合、nullが返る
- **カテゴリ**: 境界値
- **対象メソッド**: findById()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: id='not-exist'
- **操作手順**: `findById('not-exist')` を呼ぶ
- **期待結果**: nullが返る（`rows.isEmpty`分岐）

### テストケース14: folderIdとuserIdの両方が一致するレコードのみ取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findByFolderId()
- **事前条件**: 自ユーザー/folder-1、他ユーザー/folder-1、自ユーザー/folder-2 の3件をinsert
- **入力値・テスト条件**: folderId='folder-1', userId=自ユーザー
- **操作手順**: `findByFolderId('folder-1', userId: userId)` を呼ぶ
- **期待結果**: 自ユーザー・folder-1の1件のみ返る

### テストケース15: 該当レコードが0件の場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: findByFolderId()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: folderId='folder-1'
- **操作手順**: `findByFolderId('folder-1', userId: userId)` を呼ぶ
- **期待結果**: 空リストが返る

### テストケース16: 複数件存在する場合、createdAt昇順で返る
- **カテゴリ**: 正常系
- **対象メソッド**: findByFolderId()
- **事前条件**: createdAtが新しいword-newと古いword-oldをinsert（insert順は新→旧）
- **入力値・テスト条件**: folderId='folder-1'
- **操作手順**: `findByFolderId('folder-1', userId: userId)` を呼ぶ
- **期待結果**: `['word-old', 'word-new']`の順で返る（orderBy: createdAt ASC）

### テストケース17: 新規IDの場合、レコードが挿入される
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: id='word-1'
- **操作手順**: `upsert(word, ...)` を呼び、findByIdで確認
- **期待結果**: レコードが取得できる

### テストケース18: 既存IDの場合、レコードが上書きされる
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: 'word-1'（front='old-front'）がinsert済み
- **入力値・テスト条件**: 同一idでfront='new-front'をupsert
- **操作手順**: upsert後にfindById、DB直接クエリでレコード数を確認
- **期待結果**: frontが'new-front'に置き換わり、レコード数は1件のまま

### テストケース19: syncStatusを指定しない場合、synced として保存される
- **カテゴリ**: 境界値
- **対象メソッド**: upsert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: syncStatus引数なし（upsert()はsyncStatusを受け取らずデフォルト値を使う）
- **操作手順**: upsert後にDBを直接クエリ
- **期待結果**: syncStatus列が'synced'

### テストケース20: 指定したfolderIdのレコードが全て削除される
- **カテゴリ**: 正常系
- **対象メソッド**: deleteByFolderId()
- **事前条件**: folder-1に2件、folder-2に1件insert済み
- **入力値・テスト条件**: folderId='folder-1'
- **操作手順**: `deleteByFolderId('folder-1')` を呼び、双方のfolderをfindByFolderIdで確認
- **期待結果**: folder-1は空リスト、folder-2は影響を受けず1件残る

### テストケース21: 該当レコードが存在しない場合でも例外が発生せず正常終了する
- **カテゴリ**: 異常系
- **対象メソッド**: deleteByFolderId()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: folderId='not-exist-folder'
- **操作手順**: `deleteByFolderId('not-exist-folder')` を呼ぶ
- **期待結果**: 例外を投げず`Future`が正常完了する（`completes`）

### テストケース22: insertした場合、DBに保存されるcreatedAt/updatedAtがUTCのISO8601文字列(末尾Z)になる
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: createdAt/updatedAtにローカル時刻を指定
- **操作手順**: insert後にDBを直接クエリしてcreatedAt/updatedAt列を確認
- **期待結果**: 両列とも末尾が'Z'の文字列（UTC）になっている

### テストケース23: Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる
- **カテゴリ**: 境界値
- **対象メソッド**: findById()
- **事前条件**: 'word-1'がinsert済み
- **入力値・テスト条件**: DBのcreatedAt列を末尾'Z'の無い旧バージョン1形式の文字列に直接書き換える
- **操作手順**: `findById('word-1')` を呼ぶ
- **期待結果**: 書き換えた文字列と同じ`DateTime`（端末のタイムゾーンの時刻として解釈）が返る

### テストケース24: deletedAtが設定された単語を指定した場合、findByIdは削除済みでも取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findById()
- **事前条件**: 'word-1'がinsert済みで`markDeleted`済み
- **入力値・テスト条件**: id='word-1'
- **操作手順**: `findById('word-1')` を呼ぶ
- **期待結果**: 削除済みでもWordが返る（`findById`はdeletedAtで絞り込まない）

### テストケース25: deletedAtが設定された単語が存在する場合、findByFolderIdの結果に含まれない
- **カテゴリ**: 正常系
- **対象メソッド**: findByFolderId()
- **事前条件**: 同一folderに'word-1'（削除済み）・'word-2'（未削除）がinsert済み
- **入力値・テスト条件**: folderId='folder-1', userId=自ユーザー
- **操作手順**: `findByFolderId('folder-1', userId: userId)` を呼ぶ
- **期待結果**: 'word-2'のみ返る（'word-1'は`deletedAt IS NULL`条件で除外）

### テストケース26: 自ユーザーの未削除の単語を指定した場合、その単語が取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findActive()
- **事前条件**: 'word-1'が自ユーザーでinsert済み
- **入力値・テスト条件**: wordId='word-1', userId=自ユーザー
- **操作手順**: `findActive(db, 'word-1', userId: userId)` を呼ぶ
- **期待結果**: 該当するWordが返る

### テストケース27: 削除済みの単語を指定した場合、findActiveはnullを返す
- **カテゴリ**: 異常系
- **対象メソッド**: findActive()
- **事前条件**: 'word-1'がinsert済みで`markDeleted`済み
- **入力値・テスト条件**: wordId='word-1', userId=自ユーザー
- **操作手順**: `findActive(db, 'word-1', userId: userId)` を呼ぶ
- **期待結果**: nullが返る

### テストケース28: 他ユーザーの単語を指定した場合、findActiveはnullを返す
- **カテゴリ**: 異常系
- **対象メソッド**: findActive()
- **事前条件**: 'word-1'が他ユーザーでinsert済み
- **入力値・テスト条件**: wordId='word-1', userId=自ユーザー
- **操作手順**: `findActive(db, 'word-1', userId: userId)` を呼ぶ
- **期待結果**: nullが返る

### テストケース29: 未削除の単語のみが存在する場合、それらのidが取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findActiveIdsByFolder()
- **事前条件**: 同一folderに'word-1'（未削除）・'word-2'（削除済み）が自ユーザーでinsert済み
- **入力値・テスト条件**: folderId='folder-1', userId=自ユーザー
- **操作手順**: `findActiveIdsByFolder(db, 'folder-1', userId: userId)` を呼ぶ
- **期待結果**: `['word-1']`のみ返る

### テストケース30: 他ユーザーの単語が存在する場合、そのidは含まれない
- **カテゴリ**: 異常系
- **対象メソッド**: findActiveIdsByFolder()
- **事前条件**: 'word-1'が他ユーザーでinsert済み
- **入力値・テスト条件**: folderId='folder-1', userId=自ユーザー
- **操作手順**: `findActiveIdsByFolder(db, 'folder-1', userId: userId)` を呼ぶ
- **期待結果**: 空リストが返る

### テストケース31: 未登録の単語をsaveした場合、新規レコードとして挿入される
- **カテゴリ**: 正常系
- **対象メソッド**: save()
- **事前条件**: テーブルが空
- **入力値・テスト条件**: id='word-1'
- **操作手順**: `save(db, word, userId: userId, folderId: 'folder-1')` を呼び、findByIdで確認
- **期待結果**: レコードが取得できる

### テストケース32: 既存IDの単語をsaveした場合、レコードが置き換えられる（重複せず1件のまま）
- **カテゴリ**: 正常系
- **対象メソッド**: save()
- **事前条件**: 'word-1'（front='旧'）が既に`save`済み
- **入力値・テスト条件**: 同一idでfront='新'を再度save
- **操作手順**: 2回目のsave後にfindByFolderIdで確認
- **期待結果**: レコード数が1件のまま、frontが'新'に置き換わる

### テストケース33: 存在する単語をmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる
- **カテゴリ**: 正常系
- **対象メソッド**: markDeleted()
- **事前条件**: 'word-1'がinsert済み
- **入力値・テスト条件**: deletedAt=DateTime(2024, 4, 1, 9, 0)
- **操作手順**: `markDeleted(db, 'word-1', deletedAt)` を呼び、DBを直接クエリ・findByIdで確認
- **期待結果**: syncStatus列が'pending'になり、findByIdのupdatedAtがdeletedAtと一致する
