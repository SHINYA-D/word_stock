# sync_service_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/sync/sync_service.dart |
| クラス名 | SyncService |
| テスト対象メソッド | syncLocalToRemote() / syncRemoteToLocalOnLogin() / syncRemoteToLocalOnResumed() / _processQueueItem()・_buildPath()・_convertToFirestoreData()・_isIso8601()・_upsertFolderWithConflictCheck()・_upsertWordWithConflictCheck()・_upsertFlashcardResultWithConflictCheck()・_upsertSettingsWithConflictCheck()・_updateLastSyncedAt()・_getLastSyncedAt()（いずれもprivate、公開メソッド経由で間接的に検証） |

## 実行環境について

`SyncService` は SQLite(sqflite)・Firestore・ネットワーク接続監視に依存するため、
以下の方針で Dart Pure Test として実行できるようにしている。

- **SQLite**: `sqflite_common_ffi` を dev_dependency として使用し、実際の SQLite エンジンを
  テスト専用の一時ディレクトリ上のファイルとして使用する（`DatabaseHelper` / `SyncQueueDataSource`
  は実クラスをそのまま使用し、`folders` / `words` / `flashcard_results` / `settings` /
  `sync_queue` / `sync_meta` の各テーブルへの実際の読み書きを検証する）。
- **Firestore**: `SyncService` は `FirestoreDataSource` のような抽象を持たず、
  `cloud_firestore` の `FirebaseFirestore` を直接コンストラクタで受け取る実装になっている。
  実 Firebase を初期化せずに検証するため、本テストでは dev_dependency として
  `fake_cloud_firestore`（`FakeFirebaseFirestore`）を新規追加し、`doc()` / `collection()` /
  `where()` / `runTransaction()` をインメモリで再現している。
- **ネットワーク接続**: `ConnectivityMonitor` を `implements` した
  `test/helpers/fake_infrastructure.dart` の `FakeConnectivityMonitor` でオンライン/オフラインを固定する。
- **ユーザーID**: コンストラクタ引数 `getCurrentUserId` にテストローカル変数を返すクロージャを渡し、
  `null` / 非 `null` を自由に切り替える。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | オフラインの場合、キューは処理されずFirestoreにも書き込まれない | 異常系 | syncLocalToRemote() | ✅ |
| 2 | ユーザーIDがnullの場合、キューは処理されない | 異常系 | syncLocalToRemote() | ✅ |
| 3 | フォルダのupsert操作の場合、Firestoreに書き込まれキューから削除される | 正常系 | syncLocalToRemote() / _processQueueItem() / _buildPath() | ✅ |
| 4 | 単語のupsert操作でparentIdが指定されている場合、正しいパスに書き込まれる | 正常系 | syncLocalToRemote() / _buildPath() | ✅ |
| 5 | 単語のupsert操作でparentIdがnullの場合、例外が発生し同期が中断されキューに残る | 異常系 | _buildPath() | ✅ |
| 6 | 成績データのupsert操作の場合、Firestoreに書き込まれる | 正常系 | syncLocalToRemote() / _buildPath() | ✅ |
| 7 | 設定のupsert操作の場合、Firestoreに書き込まれる | 正常系 | syncLocalToRemote() / _buildPath() | ✅ |
| 8 | 不明なtable_nameの場合、例外が発生し同期が中断されキューに残る | 異常系 | _buildPath() | ✅ |
| 9 | delete操作の場合、Firestoreからドキュメントが削除されキューから削除される | 正常系 | syncLocalToRemote() / _processQueueItem() | ✅ |
| 10 | リモートの方が新しい場合、競合解決により書き込みがスキップされる | 境界値 | _processQueueItem() | ✅ |
| 11 | ローカルの方が新しい場合、競合解決によりFirestoreが上書きされる | 境界値 | _processQueueItem() | ✅ |
| 12 | 複数キューがある場合、途中で失敗すると以降のアイテムは未処理のまま残る | 異常系 | syncLocalToRemote() | ✅ |
| 13 | payloadに非ISO8601文字列や真偽値が含まれる場合、日付以外はそのままの型で書き込まれる | 境界値 | _convertToFirestoreData() / _isIso8601() | ✅ |
| 14 | ユーザーIDがnullの場合、何も同期されない（ログイン時） | 異常系 | syncRemoteToLocalOnLogin() | ✅ |
| 15 | Firestoreのfolders/words/flashcard_results/settingsが全てローカルDBに反映される | 正常系 | syncRemoteToLocalOnLogin() | ✅ |
| 16 | 設定ドキュメントが存在しない場合、ローカルのsettingsテーブルは更新されない | 境界値 | syncRemoteToLocalOnLogin() | ✅ |
| 17 | settingsドキュメントにupdatedAtフィールドが無い場合、現在時刻を用いて登録される | 境界値 | _upsertSettingsWithConflictCheck() | ✅ |
| 18 | ローカルのsyncStatusがpendingの場合、リモートの内容で上書きされない（フォルダ） | 境界値 | _upsertFolderWithConflictCheck() | ✅ |
| 19 | ローカルのupdatedAtがリモートより新しい場合、上書きされない（フォルダ） | 境界値 | _upsertFolderWithConflictCheck() | ✅ |
| 20 | 単語のローカルsyncStatusがpendingの場合、リモートの内容で上書きされない | 境界値 | _upsertWordWithConflictCheck() | ✅ |
| 21 | 単語のローカルupdatedAtがリモートより新しい場合、上書きされない | 境界値 | _upsertWordWithConflictCheck() | ✅ |
| 22 | 成績データのローカルsyncStatusがpendingの場合、リモートの内容で上書きされない | 境界値 | _upsertFlashcardResultWithConflictCheck() | ✅ |
| 23 | 成績データのローカルupdatedAtがリモートより新しい場合、上書きされない | 境界値 | _upsertFlashcardResultWithConflictCheck() | ✅ |
| 24 | 設定のローカルsyncStatusがpendingの場合、リモートの内容で上書きされない | 境界値 | _upsertSettingsWithConflictCheck() | ✅ |
| 25 | 設定のローカルupdatedAtがリモートより新しい場合、上書きされない | 境界値 | _upsertSettingsWithConflictCheck() | ✅ |
| 26 | オフラインの場合、何も同期されない（resumed時） | 異常系 | syncRemoteToLocalOnResumed() | ✅ |
| 27 | lastSyncedAtが5分以内の場合、スロットルされ同期は行われない | 境界値 | syncRemoteToLocalOnResumed() | ✅ |
| 28 | lastSyncedAtが5分より前の場合、差分同期が実行される | 境界値 | syncRemoteToLocalOnResumed() | ✅ |
| 29 | lastSyncedAtが存在しない場合、1970年からの差分として同期が実行される | 境界値 | syncRemoteToLocalOnResumed() / _getLastSyncedAt() | ✅ |
| 30 | ユーザーIDがnullの場合、同期は実行されない（resumed時） | 異常系 | syncRemoteToLocalOnResumed() | ✅ |
| 31 | フォルダに単語の差分が無い場合、そのフォルダの単語同期はスキップされる | 境界値 | syncRemoteToLocalOnResumed() | ✅ |
| 32 | フォルダに単語の差分がある場合、その単語がローカルに反映される | 正常系 | syncRemoteToLocalOnResumed() | ✅ |
| 33 | 成績データに差分がある場合、ローカルに反映される | 正常系 | syncRemoteToLocalOnResumed() | ✅ |
| 34 | 設定がlastSyncedAtより後に更新されている場合、ローカルに反映される | 正常系 | syncRemoteToLocalOnResumed() | ✅ |
| 35 | 設定がlastSyncedAt以前にしか更新されていない場合、ローカルへの反映はスキップされる | 境界値 | syncRemoteToLocalOnResumed() | ✅ |

## テストケース詳細

### テストケース1: オフラインの場合、キューは処理されずFirestoreにも書き込まれない
- **カテゴリ**: 異常系
- **対象メソッド**: syncLocalToRemote()
- **事前条件**: `FakeConnectivityMonitor` をオフラインに設定。`sync_queue` にフォルダのupsertアイテムを1件登録。
- **入力値・テスト条件**: `connectivityMonitor.isOnline()` が `false` を返す。
- **操作手順**: `syncLocalToRemote(connectivityMonitor: connectivity)` を呼び出す。
- **期待結果**: `sync_queue` の件数が1件のまま変化しない。Firestoreの `folders` コレクションにドキュメントが作成されない。

### テストケース2: ユーザーIDがnullの場合、キューは処理されない
- **カテゴリ**: 異常系
- **対象メソッド**: syncLocalToRemote()
- **事前条件**: `getCurrentUserId` が `null` を返すようにする。オンライン状態。`sync_queue` にアイテム1件登録。
- **入力値・テスト条件**: `userId == null`
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: `sync_queue` の件数が1件のまま変化しない。

### テストケース3: フォルダのupsert操作の場合、Firestoreに書き込まれキューから削除される
- **カテゴリ**: 正常系
- **対象メソッド**: syncLocalToRemote() / _processQueueItem() / _buildPath()
- **事前条件**: オンライン、ユーザーID有効。`sync_queue` に `table_name=folders`, `operation=upsert` のアイテムを登録。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: `users/{userId}/folders/f1` にドキュメントが作成され、`name` が payload の値と一致する。`updatedAt` は `Timestamp` 型に変換されている。`sync_queue` は空になる。

### テストケース4: 単語のupsert操作でparentIdが指定されている場合、正しいパスに書き込まれる
- **カテゴリ**: 正常系
- **対象メソッド**: syncLocalToRemote() / _buildPath()
- **事前条件**: `sync_queue` に `table_name=words`, `parent_id=f1` のアイテムを登録。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: `users/{userId}/folders/f1/words/w1` にドキュメントが作成される。`sync_queue` は空になる。

### テストケース5: 単語のupsert操作でparentIdがnullの場合、例外が発生し同期が中断されキューに残る
- **カテゴリ**: 異常系
- **対象メソッド**: _buildPath()
- **事前条件**: `sync_queue` に `table_name=words`, `parent_id=null` のアイテムを登録。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: `_buildPath()` が `Exception('parentId is required for words')` を送出し、`syncLocalToRemote()` のループが `break` する。アイテムは削除されず `sync_queue` に1件残る。Firestoreの `words` コレクションは空のまま。

### テストケース6: 成績データのupsert操作の場合、Firestoreに書き込まれる
- **カテゴリ**: 正常系
- **対象メソッド**: syncLocalToRemote() / _buildPath()
- **操作手順**: `table_name=flashcard_results` のアイテムを登録し `syncLocalToRemote()` を呼び出す。
- **期待結果**: `users/{userId}/flashcard_results/r1` にドキュメントが作成され、`totalCount` が一致する。

### テストケース7: 設定のupsert操作の場合、Firestoreに書き込まれる
- **カテゴリ**: 正常系
- **対象メソッド**: syncLocalToRemote() / _buildPath()
- **操作手順**: `table_name=settings` のアイテムを登録し `syncLocalToRemote()` を呼び出す。
- **期待結果**: `users/{userId}/settings/config` にドキュメントが作成され、`colorTheme` が一致する。

### テストケース8: 不明なtable_nameの場合、例外が発生し同期が中断されキューに残る
- **カテゴリ**: 異常系
- **対象メソッド**: _buildPath()
- **操作手順**: `table_name='unknown_table'` のアイテムを登録し `syncLocalToRemote()` を呼び出す。
- **期待結果**: `Exception('Unknown table_name: ...')` が送出され `break` する。アイテムは `sync_queue` に残る。

### テストケース9: delete操作の場合、Firestoreからドキュメントが削除されキューから削除される
- **カテゴリ**: 正常系
- **対象メソッド**: syncLocalToRemote() / _processQueueItem()
- **事前条件**: Firestoreに `users/{userId}/folders/f1` を事前作成。`sync_queue` に `operation=delete` のアイテムを登録。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: 対象ドキュメントが削除され (`exists == false`)、`sync_queue` は空になる。

### テストケース10: リモートの方が新しい場合、競合解決により書き込みがスキップされる
- **カテゴリ**: 境界値
- **対象メソッド**: _processQueueItem()
- **事前条件**: リモートに `updatedAt=2024-06-01`, `name='remote-name'` のドキュメントが存在。ローカルの payload は `updatedAt=2024-01-01`, `name='local-name'`。
- **入力値・テスト条件**: `remoteUpdatedAt.isAfter(localUpdatedAt) == true`
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: Firestoreドキュメントの `name` は `'remote-name'` のまま変化しない（`transaction.set` がスキップされる）。例外ではないため `sync_queue` からは削除される。

### テストケース11: ローカルの方が新しい場合、競合解決によりFirestoreが上書きされる
- **カテゴリ**: 境界値
- **対象メソッド**: _processQueueItem()
- **事前条件**: リモートは `updatedAt=2024-01-01`, ローカル payload は `updatedAt=2024-06-01`。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: Firestoreドキュメントの `name` が `'local-name'` に更新される。

### テストケース12: 複数キューがある場合、途中で失敗すると以降のアイテムは未処理のまま残る
- **カテゴリ**: 異常系
- **対象メソッド**: syncLocalToRemote()
- **事前条件**: `created_at` 昇順で「parentIdなしの単語（例外）」→「正常なフォルダ」の順にキューを2件登録。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: 1件目で例外が発生し `break` するため、2件目（正常なフォルダ）は未処理のまま。`sync_queue` の件数は2件のまま、Firestoreにも書き込まれない。

### テストケース13: payloadに非ISO8601文字列や真偽値が含まれる場合、日付以外はそのままの型で書き込まれる
- **カテゴリ**: 境界値
- **対象メソッド**: _convertToFirestoreData() / _isIso8601()
- **事前条件**: payload に ISO8601文字列の `createdAt`、非ISO8601文字列 `note`、真偽値 `flag`、数値 `count` を含める。
- **操作手順**: `syncLocalToRemote()` を呼び出す。
- **期待結果**: Firestoreに書き込まれたデータで `createdAt` は `Timestamp` 型、`note`/`flag`/`count` はそれぞれ元の型・値のまま保持される。

### テストケース14: ユーザーIDがnullの場合、何も同期されない（ログイン時）
- **カテゴリ**: 異常系
- **対象メソッド**: syncRemoteToLocalOnLogin()
- **事前条件**: `getCurrentUserId` が `null` を返す。Firestoreにフォルダドキュメントが存在。
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカルDBの `folders` テーブルは空のまま。`sync_meta` に `lastSyncedAt` も登録されない。

### テストケース15: Firestoreのfolders/words/flashcard_results/settingsが全てローカルDBに反映される
- **カテゴリ**: 正常系
- **対象メソッド**: syncRemoteToLocalOnLogin()
- **事前条件**: Firestoreにフォルダ・そのフォルダ配下の単語・成績データ・設定ドキュメントをそれぞれ1件ずつ用意。
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカルDBの `folders`/`words`/`flashcard_results`/`settings` 各テーブルに1件ずつ登録され、`syncStatus` は `'synced'`。`sync_meta.lastSyncedAt` が新規登録される。

### テストケース16: 設定ドキュメントが存在しない場合、ローカルのsettingsテーブルは更新されない
- **カテゴリ**: 境界値
- **対象メソッド**: syncRemoteToLocalOnLogin()
- **事前条件**: Firestoreにフォルダのみ存在し、settingsドキュメントは作成しない。
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカルDBの `settings` テーブルは空のまま。

### テストケース17: settingsドキュメントにupdatedAtフィールドが無い場合、現在時刻を用いて登録される
- **カテゴリ**: 境界値
- **対象メソッド**: _upsertSettingsWithConflictCheck()
- **事前条件**: Firestoreのsettingsドキュメントに `updatedAt` フィールドを含めない（`colorTheme`/`darkMode` のみ）。
- **入力値・テスト条件**: `remoteUpdatedAtRaw is Timestamp == false`
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカルDBの `settings.updatedAt` が現在時刻（1分以内の差）で登録される（`DateTime.now()` フォールバック分岐）。

### テストケース18: ローカルのsyncStatusがpendingの場合、リモートの内容で上書きされない（フォルダ）
- **カテゴリ**: 境界値
- **対象メソッド**: _upsertFolderWithConflictCheck()
- **事前条件**: ローカルDBに `syncStatus='pending'` のフォルダ行を用意。Firestoreに同IDでより新しい `updatedAt` のドキュメントを用意。
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカル行の `name`/`syncStatus` は変化しない（オフライン編集中のローカル変更を保護）。

### テストケース19: ローカルのupdatedAtがリモートより新しい場合、上書きされない（フォルダ）
- **カテゴリ**: 境界値
- **対象メソッド**: _upsertFolderWithConflictCheck()
- **事前条件**: ローカル行の `updatedAt` がリモートより新しい（`syncStatus='synced'`）。
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカル行の `name` は変化しない。

### テストケース20〜21: 単語のローカルsyncStatusがpending / updatedAtが新しい場合、上書きされない
- **カテゴリ**: 境界値
- **対象メソッド**: _upsertWordWithConflictCheck()
- **事前条件**: 親フォルダのFirestoreドキュメントを用意した上で、ローカルDBに対象の単語行（`pending`、または `updatedAt` がリモートより新しい）を用意。
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカル行の `front` は変化しない。

### テストケース22〜23: 成績データのローカルsyncStatusがpending / updatedAtが新しい場合、上書きされない
- **カテゴリ**: 境界値
- **対象メソッド**: _upsertFlashcardResultWithConflictCheck()
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカル行の `correctCount` は変化しない。

### テストケース24〜25: 設定のローカルsyncStatusがpending / updatedAtが新しい場合、上書きされない
- **カテゴリ**: 境界値
- **対象メソッド**: _upsertSettingsWithConflictCheck()
- **操作手順**: `syncRemoteToLocalOnLogin()` を呼び出す。
- **期待結果**: ローカル行の `colorTheme` は変化しない。

### テストケース26: オフラインの場合、何も同期されない（resumed時）
- **カテゴリ**: 異常系
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **操作手順**: オフライン状態で `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `folders` テーブルは空のまま。

### テストケース27: lastSyncedAtが5分以内の場合、スロットルされ同期は行われない
- **カテゴリ**: 境界値
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **事前条件**: `sync_meta.lastSyncedAt` を現在時刻の2分前に設定。
- **入力値・テスト条件**: `elapsed(2min) < _syncInterval(5min)`
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: Firestoreに更新があってもローカルDBの `folders` は空のまま（早期return）。

### テストケース28: lastSyncedAtが5分より前の場合、差分同期が実行される
- **カテゴリ**: 境界値
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **事前条件**: `sync_meta.lastSyncedAt` を現在時刻の10分前に設定。
- **入力値・テスト条件**: `elapsed(10min) >= _syncInterval(5min)`
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `folders` に反映され、`sync_meta.lastSyncedAt` が更新される（元の値より新しくなる）。

### テストケース29: lastSyncedAtが存在しない場合、1970年からの差分として同期が実行される
- **カテゴリ**: 境界値
- **対象メソッド**: syncRemoteToLocalOnResumed() / _getLastSyncedAt()
- **事前条件**: `sync_meta` テーブルにレコードなし。
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: `lastSyncedAtForQuery` に `DateTime(1970)` が使われ、既存のFirestoreドキュメントが全て差分として同期される。

### テストケース30: ユーザーIDがnullの場合、同期は実行されない（resumed時）
- **カテゴリ**: 異常系
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **事前条件**: スロットルチェックを通過させるため `sync_meta` は未登録。`getCurrentUserId` は `null`。
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `folders` は空のまま。

### テストケース31: フォルダに単語の差分が無い場合、そのフォルダの単語同期はスキップされる
- **カテゴリ**: 境界値
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **事前条件**: フォルダ・単語ともに `updatedAt` が `lastSyncedAt` より古い（差分なし）。
- **入力値・テスト条件**: `wordsSnapshot.docs.isEmpty == true`
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: `continue` により該当フォルダの単語トランザクションが実行されず、ローカルDBの `folders`/`words` はともに空のまま。例外は発生しない。

### テストケース32: フォルダに単語の差分がある場合、その単語がローカルに反映される
- **カテゴリ**: 正常系
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **事前条件**: フォルダ自体は差分なし、配下の単語のみ `lastSyncedAt` より新しい `updatedAt`。
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `words` テーブルに当該単語が1件反映される。

### テストケース33: 成績データに差分がある場合、ローカルに反映される
- **カテゴリ**: 正常系
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **操作手順**: `updatedAt` が `lastSyncedAt` より新しい成績データをFirestoreに用意し `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `flashcard_results` テーブルに反映される。

### テストケース34: 設定がlastSyncedAtより後に更新されている場合、ローカルに反映される
- **カテゴリ**: 正常系
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **入力値・テスト条件**: `remoteUpdatedAt.isAfter(lastSyncedAtForQuery) == true`
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `settings` テーブルに反映される。

### テストケース35: 設定がlastSyncedAt以前にしか更新されていない場合、ローカルへの反映はスキップされる
- **カテゴリ**: 境界値
- **対象メソッド**: syncRemoteToLocalOnResumed()
- **入力値・テスト条件**: `remoteUpdatedAt.isAfter(lastSyncedAtForQuery) == false`
- **操作手順**: `syncRemoteToLocalOnResumed()` を呼び出す。
- **期待結果**: ローカルDBの `settings` テーブルは空のまま。

## 対象外

なし（限定分母カバレッジ 100%、未カバー行なし）。
