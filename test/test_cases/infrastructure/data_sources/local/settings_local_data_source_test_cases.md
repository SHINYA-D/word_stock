# settings_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/settings_local_data_source.dart |
| クラス名 | SettingsLocalDataSource |
| テスト対象メソッド | upsert() / findByUserId()（_toRow() / _toSettings() はprivateのため両メソッド経由で間接的に検証） |

## 実行環境について

`SettingsLocalDataSource` は SQLite(sqflite) に依存するため、`sqflite_common_ffi` を用いて
実際の SQLite エンジンをテスト専用の一時ディレクトリ上のファイルとして使用する
（`DatabaseHelper` は実クラスをそのまま使用）。他のテストファイルとのDBファイルロック競合を
避けるため、`Directory.systemTemp.createTemp()` でこのテストファイル専用の一時ディレクトリを
`setUpAll` で確保し、`setUp` で毎回 `settings` テーブルをクリアしている。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 新規レコードをupsertした場合、findByUserIdで同じ値が取得できる（DateTimeの往復変換を含む） | 正常系 | upsert() / findByUserId() | ✅ |
| 2 | darkModeがfalseの場合、0として保存され取得時にfalseへ変換される | 正常系 | upsert() / findByUserId() | ✅ |
| 3 | syncStatusを指定した場合、その値がsyncStatusカラムに保存される | 正常系 | upsert() | ✅ |
| 4 | 別のuserIdのレコードが存在する場合、指定したuserIdのレコードのみ取得できる | 正常系 | findByUserId() | ✅ |
| 5 | 存在しないuserIdを指定した場合、nullが返る | 異常系 | findByUserId() | ✅ |
| 6 | 同じuserIdで2回upsertした場合、レコードが上書きされ最新の値のみ取得できる | 境界値 | upsert() | ✅ |
| 7 | updatedAtがnullの場合、現在時刻が採用され取得時にnullではない値が返る | 境界値 | upsert() / findByUserId() | ✅ |

## テストケース詳細

### テストケース1: 新規レコードをupsertした場合、findByUserIdで同じ値が取得できる（DateTimeの往復変換を含む）
- **カテゴリ**: 正常系
- **対象メソッド**: upsert() / findByUserId()
- **事前条件**: `settings`テーブルが空。
- **入力値・テスト条件**: `colorTheme: 'blue'`, `darkMode: true`, `updatedAt: DateTime(2024, 3, 1, 12, 30)` の `UserSettings` を `userId: 'user-1'` で `upsert`。
- **操作手順**: `upsert` 実行後、`findByUserId('user-1')` を呼び出す。
- **期待結果**: 返り値の `colorTheme`, `darkMode`, `updatedAt` が入力値と完全一致する（DateTime→ISO8601文字列→DateTimeの往復変換が正しい）。

### テストケース2: darkModeがfalseの場合、0として保存され取得時にfalseへ変換される
- **カテゴリ**: 正常系
- **対象メソッド**: upsert() / findByUserId()
- **事前条件**: `settings`テーブルが空。
- **入力値・テスト条件**: `darkMode: false` の `UserSettings` を `upsert`。
- **操作手順**: `upsert` 実行後、`findByUserId` を呼び出す。
- **期待結果**: 返り値の `darkMode` が `false`（INTEGER 0 → bool false の変換が正しい）。

### テストケース3: syncStatusを指定した場合、その値がsyncStatusカラムに保存される
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: `settings`テーブルが空。
- **入力値・テスト条件**: `syncStatus: 'pending'` を指定して `upsert`（デフォルト値`'synced'`ではない値を明示指定する分岐）。
- **操作手順**: `upsert` 実行後、`DatabaseHelper.database` から直接 `settings` テーブルを `query` する。
- **期待結果**: 取得した行の `syncStatus` カラムが `'pending'`。

### テストケース4: 別のuserIdのレコードが存在する場合、指定したuserIdのレコードのみ取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findByUserId()
- **事前条件**: `userId: 'user-1'` と `userId: 'other-user'` の2レコードが存在。
- **入力値・テスト条件**: `findByUserId('user-1')` を呼び出す。
- **操作手順**: 2件をupsert後、対象userIdのみで検索する。
- **期待結果**: `'user-1'` の値（`colorTheme: 'blue'`）のみが返る。

### テストケース5: 存在しないuserIdを指定した場合、nullが返る
- **カテゴリ**: 異常系
- **対象メソッド**: findByUserId()
- **事前条件**: `settings`テーブルが空。
- **入力値・テスト条件**: `findByUserId('not-exist')`。
- **操作手順**: レコードが1件も無い状態で検索を実行する。
- **期待結果**: `null` が返る（`rows.isEmpty` 分岐）。

### テストケース6: 同じuserIdで2回upsertした場合、レコードが上書きされ最新の値のみ取得できる
- **カテゴリ**: 境界値
- **対象メソッド**: upsert()
- **事前条件**: `userId: 'user-1'` で1件目（`colorTheme: 'blue'`）をupsert済み。
- **入力値・テスト条件**: 同じ`userId`で2件目（`colorTheme: 'green'`, `darkMode: false`）をupsert（`userId`はPRIMARY KEYのためINSERT OR REPLACEで上書きされる）。
- **操作手順**: 2回upsertした後、`settings`テーブルの行数を直接確認し、`findByUserId`で内容を確認する。
- **期待結果**: テーブルの行数が1件のまま、内容は2件目の値（`colorTheme: 'green'`）に更新されている。

### テストケース7: updatedAtがnullの場合、現在時刻が採用され取得時にnullではない値が返る
- **カテゴリ**: 境界値
- **対象メソッド**: upsert() / findByUserId()
- **事前条件**: `settings`テーブルが空。
- **入力値・テスト条件**: `updatedAt: null` の `UserSettings` を `upsert`（`_toRow`内の `settings.updatedAt ?? DateTime.now()` 分岐）。
- **操作手順**: upsert実行前後の時刻を記録し、`findByUserId`で取得した`updatedAt`がその範囲内に収まることを確認する。
- **期待結果**: `updatedAt`が`null`にならず、upsert実行前後の時刻の範囲内（±1秒の許容）に収まる。

## 対象外

なし（全行がテストでカバーされる想定）。
