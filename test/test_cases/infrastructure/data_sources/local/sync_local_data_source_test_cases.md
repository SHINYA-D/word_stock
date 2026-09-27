# sync_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/sync_local_data_source.dart |
| クラス名 | SyncLocalDataSource |
| テスト対象メソッド | put() / find() / markSynced() / markDeleted() / isFolderDeleted() / activeDescendants() / readMeta() / writeMeta() / readMetaDate() / writeMetaDate() / tableOf() / entityOf() |

## 実行環境について

`SyncLocalDataSource` は SQLite(sqflite) にのみ依存するため、`sqflite_common_ffi` を使い、
テスト専用の一時ディレクトリ上のファイル DB（`DatabaseHelper` を実クラスのまま使用）に対して検証する。
Firestore・ネットワーク接続には依存しない。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | folderのレコードをputした場合、findでname/parentFolderId/createdAtが復元される | 正常系 | put() / find() | ✅ |
| 2 | wordのレコードをputした場合、parentIdがfolderId列に入りfindで復元される | 正常系 | put() / find() | ✅ |
| 3 | flashcardResultのレコードをputした場合、findで復元されparentIdはnullになる | 正常系 | put() / find() | ✅ |
| 4 | settingsのレコードをputした場合、darkModeがboolとして復元されdeletedAtは常にnullになる | 正常系 | put() / find() | ✅ |
| 5 | settingsのレコードをputした場合、userId列にはput呼び出し時のuserId引数が入る（record.idではない） | 境界値 | put() | ✅ |
| 6 | pending:falseでputした場合、findのpendingがfalseになる | 正常系 | put() / find() | ✅ |
| 7 | 存在しないidをfindした場合、nullが返る | 異常系 | find() | ✅ |
| 8 | 他ユーザーが所有するレコードをfindした場合、nullが返る | 異常系 | find() | ✅ |
| 9 | pendingなレコードをmarkSyncedした場合、findのpendingがfalseになる | 正常系 | markSynced() | ✅ |
| 10 | 存在するレコードをmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる | 正常系 | markDeleted() | ✅ |
| 11 | deletedAtが設定されたフォルダの場合、trueが返る | 正常系 | isFolderDeleted() | ✅ |
| 12 | 未削除のフォルダの場合、falseが返る | 正常系 | isFolderDeleted() | ✅ |
| 13 | 存在しないフォルダIDの場合、falseが返る | 境界値 | isFolderDeleted() | ✅ |
| 14 | 他ユーザーが所有する削除済みフォルダの場合、falseが返る | 異常系 | isFolderDeleted() | ✅ |
| 15 | 未削除の単語・成績・サブフォルダのみが再帰的に集められ、削除済み・他ユーザーのデータは含まれない | 正常系 | activeDescendants() | ✅ |
| 16 | 配下にデータが無いフォルダの場合、空リストが返る | 境界値 | activeDescendants() | ✅ |
| 17 | 未登録のkeyをreadMetaした場合、nullが返る | 異常系 | readMeta() | ✅ |
| 18 | writeMetaで書き込んだ値がreadMetaで取得できる | 正常系 | readMeta() / writeMeta() | ✅ |
| 19 | 同じkeyでwriteMetaした場合、値が置き換わる（重複せず1件のまま） | 境界値 | writeMeta() | ✅ |
| 20 | writeMetaDateで書き込んだ日時が、readMetaDateでUTCのDateTimeとして取得できる | 正常系 | readMetaDate() / writeMetaDate() | ✅ |
| 21 | 未登録のkeyをreadMetaDateした場合、nullが返る | 異常系 | readMetaDate() | ✅ |
| 22 | 全てのSyncEntityで、tableOfで得たテーブル名からentityOfが元のentityを返す | 正常系 | tableOf() / entityOf() | ✅ |

## テストケース詳細

### テストケース1: folderのレコードをputした場合、findでname/parentFolderId/createdAtが復元される
- **カテゴリ**: 正常系
- **対象メソッド**: put() / find()
- **事前条件**: DB は空
- **入力値・テスト条件**: `SyncRecord(entity: folder, id: 'folder-1', fields: {name: 'Folder A', parentFolderId: 'parent-1', createdAt: 2024-01-01T10:00Z}, updatedAt: 2024-01-02T11:00Z)`。`pending: true`
- **操作手順**: `put(db, record, userId: 'user-1', pending: true)` の後 `find(db, folder, 'folder-1', userId: 'user-1')` を呼ぶ
- **期待結果**: `pending` が true。`record.parentId` は null（folder の親フォルダ id は fields 経由）。`fields['name']`='Folder A'、`fields['parentFolderId']`='parent-1'、`fields['createdAt']`=2024-01-01T10:00Z（UTC）、`updatedAt`=2024-01-02T11:00Z（UTC）、`deletedAt`=null

### テストケース2: wordのレコードをputした場合、parentIdがfolderId列に入りfindで復元される
- **カテゴリ**: 正常系
- **対象メソッド**: put() / find()
- **事前条件**: DB は空
- **入力値・テスト条件**: `SyncRecord(entity: word, id: 'word-1', parentId: 'folder-1', fields: {front: 'apple', back: 'りんご', createdAt: ...}, updatedAt: ...)`。`pending: false`
- **操作手順**: `put` の後、`words` テーブルを直接クエリして `folderId` 列を確認し、`find` で復元結果を確認する
- **期待結果**: `words` テーブルの `folderId` 列が 'folder-1'。`find` の `pending` が false。`record.parentId`='folder-1'、`fields['front']`='apple'、`fields['back']`='りんご'

### テストケース3: flashcardResultのレコードをputした場合、findで復元されparentIdはnullになる
- **カテゴリ**: 正常系
- **対象メソッド**: put() / find()
- **事前条件**: DB は空
- **入力値・テスト条件**: `SyncRecord(entity: flashcardResult, id: 'result-1', fields: {folderId: 'folder-1', totalCount: 10, correctCount: 7, date: 2024-01-05}, updatedAt: 2024-01-06)`
- **操作手順**: `put` の後 `find` を呼ぶ
- **期待結果**: `record.parentId` が null（flashcardResult に parentColumn は無い）。`fields['folderId']`='folder-1'、`fields['totalCount']`=10、`fields['correctCount']`=7、`fields['date']`=2024-01-05（UTC）

### テストケース4: settingsのレコードをputした場合、darkModeがboolとして復元されdeletedAtは常にnullになる
- **カテゴリ**: 正常系
- **対象メソッド**: put() / find()
- **事前条件**: DB は空
- **入力値・テスト条件**: `SyncRecord(entity: settings, id: 'user-1', fields: {colorTheme: 'teal', darkMode: true}, updatedAt: ...)`
- **操作手順**: `put` の後、`settings` テーブルを直接クエリして `darkMode` 列の生値を確認し、`find` で復元結果を確認する
- **期待結果**: `settings` テーブルの `darkMode` 列が整数の 1。`find` の `fields['darkMode']` が bool の true、`fields['colorTheme']`='teal'、`deletedAt` は常に null（settings は `hasDeletedAt: false`）

### テストケース5: settingsのレコードをputした場合、userId列にはput呼び出し時のuserId引数が入る（record.idではない）
- **カテゴリ**: 境界値
- **対象メソッド**: put()
- **事前条件**: DB は空
- **入力値・テスト条件**: `SyncRecord(entity: settings, id: 'record-id-not-used', fields: {...}, updatedAt: ...)` を `userId: 'user-1'` で put する（settings の idColumn は 'userId' であり、record.id と put の userId 引数が異なる値）
- **操作手順**: `put(db, record, userId: 'user-1', pending: true)` の後、`settings` テーブルを直接クエリする
- **期待結果**: `settings` テーブルの `userId` 列が 'user-1'（record.id の 'record-id-not-used' ではない）。put の行構築でキー 'userId' が2回代入され、後勝ちで userId 引数が優先される実装であることを固定する

### テストケース6: pending:falseでputした場合、findのpendingがfalseになる
- **カテゴリ**: 正常系
- **対象メソッド**: put() / find()
- **事前条件**: DB は空
- **入力値・テスト条件**: folder レコードを `pending: false` で put
- **操作手順**: `put` の後 `find` を呼ぶ
- **期待結果**: `pending` が false

### テストケース7: 存在しないidをfindした場合、nullが返る
- **カテゴリ**: 異常系
- **対象メソッド**: find()
- **事前条件**: DB は空
- **入力値・テスト条件**: id='not-exist'
- **操作手順**: `find(db, folder, 'not-exist', userId: 'user-1')` を呼ぶ
- **期待結果**: null が返る

### テストケース8: 他ユーザーが所有するレコードをfindした場合、nullが返る
- **カテゴリ**: 異常系
- **対象メソッド**: find()
- **事前条件**: 'user-1' が所有する folder-1 が存在する
- **入力値・テスト条件**: `find(db, folder, 'folder-1', userId: 'other-user')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: null が返る（userId が一致しないため）

### テストケース9: pendingなレコードをmarkSyncedした場合、findのpendingがfalseになる
- **カテゴリ**: 正常系
- **対象メソッド**: markSynced()
- **事前条件**: folder-1 が `pending: true` で存在する
- **入力値・テスト条件**: `markSynced(db, folder, 'folder-1')`
- **操作手順**: `markSynced` の後 `find` で pending を確認する
- **期待結果**: `pending` が false

### テストケース10: 存在するレコードをmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる
- **カテゴリ**: 正常系
- **対象メソッド**: markDeleted()
- **事前条件**: word-1 が `pending: false` で存在する
- **入力値・テスト条件**: `at = 2024-04-01T09:00Z`
- **操作手順**: `markDeleted(db, word, 'word-1', at)` の後 `find` を呼ぶ
- **期待結果**: `record.deletedAt`=at、`record.updatedAt`=at、`pending`=true

### テストケース11: deletedAtが設定されたフォルダの場合、trueが返る
- **カテゴリ**: 正常系
- **対象メソッド**: isFolderDeleted()
- **事前条件**: folder-1 が存在し `markDeleted` 済み
- **入力値・テスト条件**: `isFolderDeleted(db, 'folder-1', userId: 'user-1')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: true が返る

### テストケース12: 未削除のフォルダの場合、falseが返る
- **カテゴリ**: 正常系
- **対象メソッド**: isFolderDeleted()
- **事前条件**: folder-1 が未削除で存在する
- **入力値・テスト条件**: `isFolderDeleted(db, 'folder-1', userId: 'user-1')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: false が返る

### テストケース13: 存在しないフォルダIDの場合、falseが返る
- **カテゴリ**: 境界値
- **対象メソッド**: isFolderDeleted()
- **事前条件**: DB は空
- **入力値・テスト条件**: `isFolderDeleted(db, 'not-exist', userId: 'user-1')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: false が返る

### テストケース14: 他ユーザーが所有する削除済みフォルダの場合、falseが返る
- **カテゴリ**: 異常系
- **対象メソッド**: isFolderDeleted()
- **事前条件**: 'other-user' が所有する folder-1 が削除済みで存在する
- **入力値・テスト条件**: `isFolderDeleted(db, 'folder-1', userId: 'user-1')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: false が返る（userId が一致しないため）

### テストケース15: 未削除の単語・成績・サブフォルダのみが再帰的に集められ、削除済み・他ユーザーのデータは含まれない
- **カテゴリ**: 正常系
- **対象メソッド**: activeDescendants()
- **事前条件**: root 配下に、未削除の単語 w-root・削除済みの単語 w-root-deleted・他ユーザーの単語 w-other-user・未削除の成績 r-root・削除済みの成績 r-root-deleted・未削除のサブフォルダ c1（配下に未削除の単語 w-c1）・削除済みのサブフォルダ c2（配下に未削除の単語 w-c2）を作成する
- **入力値・テスト条件**: `activeDescendants(db, 'root', userId: 'user-1')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: 結果に含まれるのは (word, w-root, parentId=root)・(flashcardResult, r-root, parentId=null)・(folder, c1, parentId=null)・(word, w-c1, parentId=c1) の4件のみ（合計4件）。w-root-deleted・w-other-user・r-root-deleted・c2・w-c2（c2 が削除済みのため配下ごと辿らない）は含まれない

### テストケース16: 配下にデータが無いフォルダの場合、空リストが返る
- **カテゴリ**: 境界値
- **対象メソッド**: activeDescendants()
- **事前条件**: DB は空
- **入力値・テスト条件**: `activeDescendants(db, 'empty-folder', userId: 'user-1')`
- **操作手順**: 上記を呼ぶ
- **期待結果**: 空リストが返る

### テストケース17: 未登録のkeyをreadMetaした場合、nullが返る
- **カテゴリ**: 異常系
- **対象メソッド**: readMeta()
- **事前条件**: sync_meta テーブルは空
- **入力値・テスト条件**: key='foo'
- **操作手順**: `readMeta('foo')` を呼ぶ
- **期待結果**: null が返る

### テストケース18: writeMetaで書き込んだ値がreadMetaで取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: readMeta() / writeMeta()
- **事前条件**: sync_meta テーブルは空
- **入力値・テスト条件**: key='foo', value='bar'
- **操作手順**: `writeMeta('foo', 'bar')` の後 `readMeta('foo')` を呼ぶ
- **期待結果**: 'bar' が返る

### テストケース19: 同じkeyでwriteMetaした場合、値が置き換わる（重複せず1件のまま）
- **カテゴリ**: 境界値
- **対象メソッド**: writeMeta()
- **事前条件**: key='foo' に 'bar' を書き込み済み
- **入力値・テスト条件**: 同じ key='foo' に 'baz' を書き込む
- **操作手順**: `writeMeta('foo', 'baz')` の後、sync_meta テーブルの行数と `readMeta('foo')` を確認する
- **期待結果**: sync_meta テーブルの行数が1件のまま。`readMeta('foo')` が 'baz' を返す

### テストケース20: writeMetaDateで書き込んだ日時が、readMetaDateでUTCのDateTimeとして取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: readMetaDate() / writeMetaDate()
- **事前条件**: sync_meta テーブルは空
- **入力値・テスト条件**: key='cursor', date=2024-05-06T07:08Z
- **操作手順**: `writeMetaDate('cursor', date)` の後 `readMetaDate('cursor')` を呼ぶ
- **期待結果**: 書き込んだ日時と同じ UTC の DateTime が返る

### テストケース21: 未登録のkeyをreadMetaDateした場合、nullが返る
- **カテゴリ**: 異常系
- **対象メソッド**: readMetaDate()
- **事前条件**: sync_meta テーブルは空
- **入力値・テスト条件**: key='not-exist'
- **操作手順**: `readMetaDate('not-exist')` を呼ぶ
- **期待結果**: null が返る

### テストケース22: 全てのSyncEntityで、tableOfで得たテーブル名からentityOfが元のentityを返す
- **カテゴリ**: 正常系
- **対象メソッド**: tableOf() / entityOf()
- **事前条件**: なし（静的メソッドのみ）
- **入力値・テスト条件**: `SyncEntity.values`（folder / word / flashcardResult / settings）の全件
- **操作手順**: 各 entity について `tableOf(entity)` からテーブル名を得て `entityOf(table)` を呼ぶ
- **期待結果**: `entityOf(tableOf(entity))` が元の entity と一致する（4種すべて）

## 対象外

- L22：`Future<Database> get database => _dbHelper.database;` という単純な委譲 getter（独自ロジックなし）。`SyncService` が取得・送信でトランザクションを開くために使い、`sync_service_test.dart` で実行される。このクラスの他メソッドは呼び出し側から `DatabaseExecutor` を受け取るため、このテストファイル単体からは通らない
