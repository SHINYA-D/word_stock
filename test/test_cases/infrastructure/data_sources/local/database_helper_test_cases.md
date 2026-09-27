# database_helper_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/database_helper.dart |
| クラス名 | DatabaseHelper |
| テスト対象メソッド | migrateToV2()（static。バージョン1 → 2 の移行） |
| 仕様書 | docs/detailed_design/online_offline/online_offline.md |

## 実行環境・観測方法について

- `sqflite_common_ffi` を使い、テスト専用の一時ディレクトリに実際の SQLite ファイル
  `wordstock.db` を作る。
- **移行の再現方法**: まずバージョン1のテーブル定義（`deletedAt` 列・`sync_queue.user_id`
  列が無い。git の `main` ブランチの `lib/infrastructure/data_sources/local/tables/*.dart`
  と同じ）で、本番と同じ物理パスに直接 DB ファイルを作ってデータを入れ、そのファイルを
  閉じてから `DatabaseHelper().database` を初めて呼ぶ。sqflite が実際に
  `onUpgrade`（oldVersion=1, newVersion=2）を呼び出し、`DatabaseHelper.migrateToV2` が
  本番と同じ経路で実行される（`DatabaseHelper.migrateToV2(db)` を直接呼ぶ方法ではなく、
  こちらを選んだ）。
- `DatabaseHelper` はシングルトンで DB パスが固定のため、この移行は `setUpAll` で
  1 回だけ行い、以降の各テストはその結果を読むだけにしている（SYN-M04 だけ、他のケースが
  使っていない別の id（フォルダ F4）で追加の取得を行い、他のテストと干渉しない）。
- 観測は、`FolderRepositoryImpl` / `WordRepositoryImpl` / `FlashcardResultRepositoryImpl` /
  `SettingsRepositoryImpl`（すべて `onLocalChanged: () {}` を渡した実クラス）の
  `getFolders` / `getWords` / `getFlashcardResults` / `getSettings` の戻り値、
  `SyncQueueDataSource.getByUser` の並び、DB の生の行（`deletedAt` は `Folder` 等の
  ドメインエンティティが持たない項目のため、生の行を直接クエリして確認する）で行う。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | バージョン1のDBにsyncedのフォルダFがある状態でDBを開いた場合、getFoldersの戻り値にFが含まれローカルのFのdeletedAtがnull [SYN-M01] | SYN-M01 #b8c362 | 正常系 | migrateToV2() | ✅ |
| 2 | バージョン1のDBにpendingのフォルダFがありキューにFの項目がない状態でDBを開いた場合、ローカルのFのsyncStatusがsyncedになる [SYN-M02] | SYN-M02 #d2ed57 | 正常系 | migrateToV2() | ✅ |
| 3 | バージョン1のDBにUのpendingのフォルダFと単語Wがありキューにキ、Wの順で項目がある状態でDBを開いた場合、ローカルのF・WのsyncStatusがpendingのままキューがF、Wの順で2件ありどちらのuserIdもU [SYN-M03] | SYN-M03 #db313d | 正常系 | migrateToV2() | ✅ |
| 4 | バージョン1のDBを開いた後、リモートにサーバー受付時刻が古いフォルダFがある状態で最初の取得をした場合、getFoldersの戻り値にFが含まれる [SYN-M04] | SYN-M04 #139287 | 正常系 | migrateToV2() | ✅ |
| 5 | バージョン1のDBにsyncedの単語W(フォルダFの中)がある状態でDBを開いた場合、getWords(F)の戻り値にWが含まれローカルのWのdeletedAtがnull [SYN-M05] | SYN-M05 #f8c82f | 正常系 | migrateToV2() | ✅ |
| 6 | バージョン1のDBにsyncedの成績Rがある状態でDBを開いた場合、getFlashcardResultsの戻り値にRが含まれローカルのRのdeletedAtがnull [SYN-M06] | SYN-M06 #ea7ff4 | 正常系 | migrateToV2() | ✅ |
| 7 | バージョン1のDBにUの設定(カラーテーマteal)がある状態でDBを開いた場合、getSettingsの戻り値のカラーテーマがteal [SYN-M07] | SYN-M07 #e0c2ce | 正常系 | migrateToV2() | ✅ |

## テストケース詳細

### テストケース1: バージョン1のDBにsyncedのフォルダFがある状態でDBを開いた場合、getFoldersの戻り値にFが含まれローカルのFのdeletedAtがnull [SYN-M01]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBファイルに、syncStatus=synced のフォルダ F1（名前「Folder1」、ユーザー U1）がある
- **入力値・テスト条件**: そのDBファイルへ `DatabaseHelper().database` で初めてアクセスする（onUpgrade 経由で移行される）
- **操作手順**: `FolderRepositoryImpl.getFolders(userId: 'U1')` を呼び、生の `folders` テーブルの F1 行を直接クエリする
- **期待結果**: `getFolders` の戻り値に F1（名前「Folder1」）が含まれる。ローカルの F1 の deletedAt が null

### テストケース2: バージョン1のDBにpendingのフォルダFがありキューにFの項目がない状態でDBを開いた場合、ローカルのFのsyncStatusがsyncedになる [SYN-M02]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBファイルに、syncStatus=pending のフォルダ F2 があり、sync_queue に F2 の項目が無い
- **入力値・テスト条件**: DB を移行後に開く
- **操作手順**: 生の `folders` テーブルの F2 行を直接クエリする
- **期待結果**: ローカルの F2 の syncStatus が synced になる

### テストケース3: バージョン1のDBにUのpendingのフォルダFと単語Wがありキューにキ、Wの順で項目がある状態でDBを開いた場合、ローカルのF・WのsyncStatusがpendingのままキューがF、Wの順で2件ありどちらのuserIdもU [SYN-M03]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBファイルに、ユーザー U1 の pending のフォルダ F3・単語 W3（F3 の中）があり、sync_queue に F3、W3 の順で（`user_id` 列が無い状態の）項目が積まれている
- **入力値・テスト条件**: DB を移行後に開く
- **操作手順**: 生の `folders`・`words` テーブルの F3・W3 行、`SyncQueueDataSource.getByUser('U1')` の結果を確認する
- **期待結果**: ローカルの F3・W3 の syncStatus が pending のまま。`getByUser('U1')` の戻り値に F3、W3 の順で2件あり（`user_id = 'U1'` で絞り込めていることで、どちらの userId も U1 になっていることを確認する）

### テストケース4: バージョン1のDBを開いた後、リモートにサーバー受付時刻が古いフォルダFがある状態で最初の取得をした場合、getFoldersの戻り値にFが含まれる [SYN-M04]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBを移行済み。移行前の旧い取得の基準（`lastSyncedAt`）は仕様どおり消え、ユーザーごとの新しい基準（`pullCursor:U1`）もまだ無い
- **入力値・テスト条件**: リモートにサーバー受付時刻が 2020-01-01（テストの他のどの時刻よりも古い）のフォルダ F4 がある
- **操作手順**: `readMeta('lastSyncedAt')` / `readMetaDate('pullCursor:U1')` が null であることを確認したうえで `SyncService.syncAll()` を呼び、`FolderRepositoryImpl.getFolders(userId: 'U1')` を呼ぶ
- **期待結果**: `getFolders` の戻り値に F4 が含まれる（取得の基準が無いため、サーバー受付時刻の新旧に関わらず全件が対象になる）

### テストケース5: バージョン1のDBにsyncedの単語W(フォルダFの中)がある状態でDBを開いた場合、getWords(F)の戻り値にWが含まれローカルのWのdeletedAtがnull [SYN-M05]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBファイルに、syncStatus=synced の単語 W5（フォルダ F1 の中、ユーザー U1）がある
- **入力値・テスト条件**: DB を移行後に開く
- **操作手順**: `WordRepositoryImpl.getWords(userId: 'U1', folderId: 'F1')` を呼び、生の `words` テーブルの W5 行を直接クエリする
- **期待結果**: `getWords(F1)` の戻り値に W5（表「front5」）が含まれる。ローカルの W5 の deletedAt が null

### テストケース6: バージョン1のDBにsyncedの成績Rがある状態でDBを開いた場合、getFlashcardResultsの戻り値にRが含まれローカルのRのdeletedAtがnull [SYN-M06]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBファイルに、syncStatus=synced の成績 R6（問題数5・正解数3、ユーザー U1）がある
- **入力値・テスト条件**: DB を移行後に開く
- **操作手順**: `FlashcardResultRepositoryImpl.getFlashcardResults(userId: 'U1')` を呼び、生の `flashcard_results` テーブルの R6 行を直接クエリする
- **期待結果**: `getFlashcardResults` の戻り値に R6（問題数5・正解数3）が含まれる。ローカルの R6 の deletedAt が null

### テストケース7: バージョン1のDBにUの設定(カラーテーマteal)がある状態でDBを開いた場合、getSettingsの戻り値のカラーテーマがteal [SYN-M07]
- **カテゴリ**: 正常系
- **対象メソッド**: migrateToV2()
- **事前条件**: バージョン1のDBファイルに、ユーザー U1 の設定（カラーテーマ「teal」）がある
- **入力値・テスト条件**: DB を移行後に開く
- **操作手順**: `SettingsRepositoryImpl.getSettings(userId: 'U1')` を呼ぶ
- **期待結果**: `getSettings` の戻り値のカラーテーマが「teal」

## 対象外

- L37-44：新規インストール（`_onCreate`、フォルダ・単語等が1件も無い状態からの DB 作成）の分岐。
  `DatabaseHelper` はシングルトンで DB パス・バージョンが固定のため、同一テストプロセス内で
  「新規インストール（onCreate）」と「バージョン1からの移行（onUpgrade → migrateToV2）」の
  両方を実クラス（Repository 経由）で検証することができない。本対象は 5.5 既存データの移行
  （SYN-M01〜M07、いずれも onUpgrade 経由）を優先して検証した。`_onCreate` 自体は
  `FolderTable.onCreate` 等（各テーブルクラス）への委譲のみで独自ロジックを持たない
