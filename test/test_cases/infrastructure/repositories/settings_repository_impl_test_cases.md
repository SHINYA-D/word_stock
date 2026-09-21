# settings_repository_impl_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/settings_repository_impl.dart |
| クラス名 | SettingsRepositoryImpl |
| テスト対象メソッド | getSettings() / updateSettings() / _mapException()（private、updateSettings経由で間接的に検証） |

## 実行環境について

`SettingsRepositoryImpl` は SQLite(sqflite)・Firestore・ネットワーク接続監視に依存するため、
以下の方針で Dart Pure Test として実行できるようにしている。

- **SQLite**: `sqflite_common_ffi` を使用し、実際の SQLite エンジンをテスト専用の一時ディレクトリ上の
  ファイルとして使用する（`SettingsLocalDataSource` / `SyncQueueDataSource` / `DatabaseHelper` は実クラスをそのまま使用）。
- **Firestore**: `FirestoreDataSource` を `implements` した手書きフェイク
  `test/helpers/fake_infrastructure.dart` の `FakeFirestoreDataSource` を使用し、実際の Firebase 通信は行わない。
- **ネットワーク接続**: `ConnectivityMonitor` を `implements` した `FakeConnectivityMonitor` でオンライン/オフラインを固定する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | ローカルに設定が保存されている場合、その設定が返る | 正常系 | getSettings() | ✅ |
| 2 | ローカルに設定が存在しない場合、デフォルトのUserSettingsが返る | 正常系 | getSettings() | ✅ |
| 3 | ローカルデータソースが例外を投げた場合、Failure.unknownが返る | 異常系 | getSettings() | ✅ |
| 4 | 設定を更新した場合、ローカル・リモート両方にsynced状態で保存される | 正常系 | updateSettings()（オンライン分岐） | ✅ |
| 5 | updatedAtが指定されていない場合でも、現在時刻が補完されて保存される | 境界値 | updateSettings()（オンライン分岐） | ✅ |
| 6 | リモート書き込みでFirebaseException(unavailable)が発生した場合、Failure.networkが返る | 異常系 | updateSettings() / _mapException() | ✅ |
| 7 | リモート書き込みでFirebaseException(network-request-failed)が発生した場合、Failure.networkが返る | 異常系 | updateSettings() / _mapException() | ✅ |
| 8 | リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る | 異常系 | updateSettings() / _mapException() | ✅ |
| 9 | リモート書き込みで一般的な例外が発生した場合、Failure.unknownが返る | 異常系 | updateSettings() | ✅ |
| 10 | 設定を更新した場合、ローカルにpending状態で保存されsync_queueにupdate登録される | 正常系 | updateSettings()（オフライン分岐） | ✅ |
| 11 | 同一ユーザーで複数回更新した場合、ローカルの設定行は1件に置き換わる | 境界値 | updateSettings()（オフライン分岐） | ✅ |

## テストケース詳細

### テストケース1: ローカルに設定が保存されている場合、その設定が返る
- **カテゴリ**: 正常系
- **対象メソッド**: getSettings()
- **事前条件**: `SettingsLocalDataSource.upsert` で `colorTheme: 'red', darkMode: true` を保存済み。
- **入力値・テスト条件**: `userId = 'user-1'`
- **操作手順**: `repository.getSettings(userId: userId)` を呼ぶ。
- **期待結果**: `Right(UserSettings(colorTheme: 'red', darkMode: true, ...))` が返る。

### テストケース2: ローカルに設定が存在しない場合、デフォルトのUserSettingsが返る
- **カテゴリ**: 正常系
- **対象メソッド**: getSettings()
- **事前条件**: `settings` テーブルが空。
- **入力値・テスト条件**: `userId = 'user-1'`
- **操作手順**: `repository.getSettings(userId: userId)` を呼ぶ。
- **期待結果**: `Right(const UserSettings())`（デフォルト値）が返る。

### テストケース3: ローカルデータソースが例外を投げた場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: getSettings()
- **事前条件**: `settings` テーブルを `DROP TABLE` し、クエリが失敗する状態にする。
- **入力値・テスト条件**: `userId = 'user-1'`
- **操作手順**: `repository.getSettings(userId: userId)` を呼ぶ。
- **期待結果**: `Left(Failure.unknown(...))`（`UnknownFailure` 型）が返る。テスト後にテーブルを復元する。

### テストケース4: 設定を更新した場合、ローカル・リモート両方にsynced状態で保存される
- **カテゴリ**: 正常系
- **対象メソッド**: updateSettings()（オンライン分岐）
- **事前条件**: `FakeConnectivityMonitor` はオンライン（デフォルト）。
- **入力値・テスト条件**: `UserSettings(colorTheme: 'blue', darkMode: true)`
- **操作手順**: `repository.updateSettings(userId: userId, settings: ...)` を呼ぶ。
- **期待結果**: `Right(unit)` が返り、ローカルDBに `colorTheme: 'blue', darkMode: true` が保存され、
  `FakeFirestoreDataSource.writtenSettings` に1件記録される。`sync_queue` には登録されない。

### テストケース5: updatedAtが指定されていない場合でも、現在時刻が補完されて保存される
- **カテゴリ**: 境界値
- **対象メソッド**: updateSettings()（オンライン分岐）
- **事前条件**: `UserSettings()`（`updatedAt: null`）を渡す。
- **入力値・テスト条件**: デフォルト値の `UserSettings`
- **操作手順**: `repository.updateSettings(userId: userId, settings: const UserSettings())` を呼ぶ。
- **期待結果**: `updateSettings()` 内部で `copyWith(updatedAt: DateTime.now())` により補完されるため、
  ローカルDBに保存された `updatedAt` が非null になる。

### テストケース6: リモート書き込みでFirebaseException(unavailable)が発生した場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings() / _mapException()
- **事前条件**: `FakeFirestoreDataSource.exceptionToThrow = FirebaseException(code: 'unavailable')`
- **入力値・テスト条件**: `UserSettings(colorTheme: 'green')`、オンライン状態
- **操作手順**: `repository.updateSettings(...)` を呼ぶ。
- **期待結果**: `Left(Failure.network())` が返る。

### テストケース7: リモート書き込みでFirebaseException(network-request-failed)が発生した場合、Failure.networkが返る
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings() / _mapException()
- **事前条件**: `FakeFirestoreDataSource.exceptionToThrow = FirebaseException(code: 'network-request-failed')`
- **入力値・テスト条件**: `UserSettings(colorTheme: 'green')`、オンライン状態
- **操作手順**: `repository.updateSettings(...)` を呼ぶ。
- **期待結果**: `Left(Failure.network())` が返る（`_mapException` の2つ目のネットワーク系コード分岐を検証）。

### テストケース8: リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings() / _mapException()
- **事前条件**: `FakeFirestoreDataSource.exceptionToThrow = FirebaseException(code: 'permission-denied', message: '権限がありません')`
- **入力値・テスト条件**: `UserSettings(colorTheme: 'green')`、オンライン状態
- **操作手順**: `repository.updateSettings(...)` を呼ぶ。
- **期待結果**: `Left(Failure.unknown('権限がありません'))` が返る（`_mapException` の `message` フォールバック分岐を検証）。

### テストケース9: リモート書き込みで一般的な例外が発生した場合、Failure.unknownが返る
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings()
- **事前条件**: `FakeFirestoreDataSource.exceptionToThrow = Exception('boom')`（`FirebaseException` ではない）
- **入力値・テスト条件**: `UserSettings(colorTheme: 'green')`、オンライン状態
- **操作手順**: `repository.updateSettings(...)` を呼ぶ。
- **期待結果**: `Left(Failure.unknown(...))` が返る（`catch (e)` の汎用例外分岐を検証）。

### テストケース10: 設定を更新した場合、ローカルにpending状態で保存されsync_queueにupdate登録される
- **カテゴリ**: 正常系
- **対象メソッド**: updateSettings()（オフライン分岐）
- **事前条件**: `FakeConnectivityMonitor.setOnline(false)`
- **入力値・テスト条件**: `UserSettings(colorTheme: 'purple', darkMode: true)`
- **操作手順**: `repository.updateSettings(...)` を呼ぶ。
- **期待結果**: `Right(unit)` が返り、`settings` テーブルに `syncStatus = 'pending'` で保存され、
  `sync_queue` に `table_name = 'settings', record_id = userId, operation = 'update'` の行が1件登録される。
  `FakeFirestoreDataSource.writtenSettings` は空のまま。

### テストケース11: 同一ユーザーで複数回更新した場合、ローカルの設定行は1件に置き換わる
- **カテゴリ**: 境界値
- **対象メソッド**: updateSettings()（オフライン分岐）
- **事前条件**: オフライン状態で `colorTheme: 'purple'` → `colorTheme: 'yellow'` の順に2回更新。
- **入力値・テスト条件**: 同一 `userId` に対する2回の `updateSettings` 呼び出し
- **操作手順**: `repository.updateSettings(...)` を2回連続で呼ぶ。
- **期待結果**: `settings` テーブルの該当行は `ConflictAlgorithm.replace` により1件のまま、
  `colorTheme` は最後に更新した `'yellow'` になる（`userId` を主キーとした置き換えを検証）。

## 対象外

- L52：`updated.updatedAt` は `updateSettings()` 冒頭で必ず `copyWith(updatedAt: DateTime.now())` により
  非nullに設定されるため、オンライン分岐内で `updated.updatedAt` が実際にnullになることはない
  （防御的な設計だが、テストケース5でこの補完自体は検証済み）。
- L68, L82：オフライン分岐内の `(updated.updatedAt ?? DateTime.now())` も同様に、呼び出し時点で
  `updated.updatedAt` は常に非nullであり、`?? DateTime.now()` 側の分岐には到達しない防御的コード。
