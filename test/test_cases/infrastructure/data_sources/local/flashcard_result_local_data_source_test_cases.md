# flashcard_result_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/flashcard_result_local_data_source.dart |
| クラス名 | FlashcardResultLocalDataSource |
| テスト対象メソッド | delete() / upsert() / findByUserId() / findActiveIdsByFolder() / save() / markDeleted()（オフライン同期対応で追加された論理削除・日時変換を含む） |

## 実行環境について

`sqflite_common_ffi` を用いて実際の SQLite エンジン（テスト専用の一時ディレクトリ）に対して
CRUD操作を行い、Dart Pure Testとして検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 存在するレコードを削除した場合、そのレコードが取得できなくなる | 正常系 | delete() | ✅ |
| 2 | 複数レコードが存在する場合、指定したIDのレコードのみが削除される | 正常系 | delete() | ✅ |
| 3 | 存在しないIDを指定して削除しても例外が発生せず正常終了する | エッジケース | delete() | ✅ |
| 4 | userIdでフィルタして一覧取得できる | 正常系（前提確認） | findByUserId() | ✅ |
| 5 | folderIdを指定した場合、そのフォルダのレコードのみ取得できる | 正常系（前提確認） | findByUserId() | ✅ |
| 6 | 存在しないIDでupsertした場合、新規レコードとして挿入される | 正常系 | upsert() | ✅ |
| 7 | 既存IDでupsertした場合、レコードが置き換えられる（重複せず1件のまま） | 正常系 | upsert() | ✅ |
| 8 | insertした場合、DBに保存されるdate/updatedAtがUTCのISO8601文字列(末尾Z)になる | 正常系 | insert() | ✅ |
| 9 | Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる | 境界値 | findByUserId() | ✅ |
| 10 | deletedAtが設定された成績が存在する場合、findByUserIdの結果に含まれない | 正常系 | findByUserId() | ✅ |
| 11 | folderIdを指定した場合でも、削除済みの成績は結果に含まれない | 境界値 | findByUserId() | ✅ |
| 12 | 未削除の成績のみが存在する場合、それらのidが取得できる | 正常系 | findActiveIdsByFolder() | ✅ |
| 13 | 他ユーザーの成績が存在する場合、そのidは含まれない | 異常系 | findActiveIdsByFolder() | ✅ |
| 14 | 未登録の成績をsaveした場合、新規レコードとして挿入される | 正常系 | save() | ✅ |
| 15 | 既存IDの成績をsaveした場合、レコードが置き換えられる（重複せず1件のまま） | 正常系 | save() | ✅ |
| 16 | 存在する成績をmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる | 正常系 | markDeleted() | ✅ |

## テストケース詳細

### テストケース1: 存在するレコードを削除した場合、そのレコードが取得できなくなる
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **入力条件**: `result-1`を1件insertした状態。
- **期待値**: `delete('result-1')`実行後、`findByUserId(userId)`が空リストを返す。
- **テストコード**:
  ```dart
  test('存在するレコードを削除した場合、そのレコードが取得できなくなる', () async {
    await dataSource.insert(makeResult('result-1', 'folder-1'), userId: userId);
    await dataSource.delete('result-1');
    final results = await dataSource.findByUserId(userId);
    expect(results, isEmpty);
  });
  ```

### テストケース2: 複数レコードが存在する場合、指定したIDのレコードのみが削除される
- **カテゴリ**: 正常系
- **対象メソッド**: delete()
- **入力条件**: `result-1`・`result-2`の2件をinsert。
- **期待値**: `delete('result-1')`実行後、`result-2`のみが残る。

### テストケース3: 存在しないIDを指定して削除しても例外が発生せず正常終了する
- **カテゴリ**: エッジケース
- **対象メソッド**: delete()
- **入力条件**: 何もinsertしていない状態で`delete('not-exist')`を呼ぶ。
- **期待値**: 例外を投げずに`Future`が正常完了する（`completes`）。

### テストケース4: userIdでフィルタして一覧取得できる
- **カテゴリ**: 正常系（前提確認）
- **対象メソッド**: findByUserId()
- **入力条件**: 自ユーザーと他ユーザーそれぞれの成績データをinsert。
- **期待値**: 自ユーザー分のみが返る。

### テストケース5: folderIdを指定した場合、そのフォルダのレコードのみ取得できる
- **カテゴリ**: 正常系（前提確認）
- **対象メソッド**: findByUserId()
- **入力条件**: 異なるfolderIdの成績データを2件insert。
- **期待値**: 指定したfolderIdのレコードのみが返る。

### テストケース6: 存在しないIDでupsertした場合、新規レコードとして挿入される
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: 未登録の`result-1`で`upsert()`を呼ぶ。
- **操作手順**: `upsert()`実行後`findByUserId()`で確認する。
- **期待結果**: 新規レコードとして取得できる。

### テストケース7: 既存IDでupsertした場合、レコードが置き換えられる（重複せず1件のまま）
- **カテゴリ**: 正常系
- **対象メソッド**: upsert()
- **事前条件**: `result-1`（totalCount: 10, correctCount: 7）をinsert済み。
- **入力値・テスト条件**: 同じIDで`totalCount`/`correctCount`/`updatedAt`を変更した内容で`upsert()`を呼ぶ。
- **操作手順**: `upsert()`実行後`findByUserId()`で全件取得する。
- **期待結果**: レコード数は1件のまま、内容が新しい値に置き換わっている（`ConflictAlgorithm.replace`の確認）。

### テストケース8: insertした場合、DBに保存されるdate/updatedAtがUTCのISO8601文字列(末尾Z)になる
- **カテゴリ**: 正常系
- **対象メソッド**: insert()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: `date: DateTime(2024,3,5,10,30)`, `updatedAt: DateTime(2024,3,6,11,45)`（端末ローカル時刻）を持つ成績を`insert()`する。
- **操作手順**: `insert()`実行後、テーブルを直接`query()`して`date`/`updatedAt`列の生の値を確認する。
- **期待結果**: `date`・`updatedAt`とも末尾が`Z`の文字列（UTC ISO8601）で保存されている。

### テストケース9: Zの無いバージョン1形式の文字列が保存されている場合、端末のタイムゾーンの時刻として読み出せる
- **カテゴリ**: 境界値
- **対象メソッド**: findByUserId()
- **事前条件**: `result-1`をinsert済み。
- **入力値・テスト条件**: `date`列を末尾`Z`の無い旧バージョン1形式の文字列（`DateTime(2024,3,5,10,30).toIso8601String()`）に直接上書きする。
- **操作手順**: `findByUserId()`で読み出す。
- **期待結果**: 読み出した`date`が端末のローカル時刻としての`DateTime(2024,3,5,10,30)`と一致する。

### テストケース10: deletedAtが設定された成績が存在する場合、findByUserIdの結果に含まれない
- **カテゴリ**: 正常系
- **対象メソッド**: findByUserId()
- **事前条件**: `result-1`・`result-2`の2件をinsert済み。
- **入力値・テスト条件**: `markDeleted()`で`result-1`を論理削除する。
- **操作手順**: `findByUserId(userId)`を呼ぶ。
- **期待結果**: `result-2`のみが返る（削除済みの`result-1`は含まれない）。

### テストケース11: folderIdを指定した場合でも、削除済みの成績は結果に含まれない
- **カテゴリ**: 境界値
- **対象メソッド**: findByUserId()
- **事前条件**: `result-1`（folder-1）をinsert済み。
- **入力値・テスト条件**: `markDeleted()`で`result-1`を論理削除した後、`folderId: 'folder-1'`を指定して`findByUserId()`を呼ぶ。
- **操作手順**: `findByUserId(userId, folderId: 'folder-1')`を呼ぶ。
- **期待結果**: 空リストが返る（`folderId`条件とdeletedAt除外条件が`AND`で両立することの確認）。

### テストケース12: 未削除の成績のみが存在する場合、それらのidが取得できる
- **カテゴリ**: 正常系
- **対象メソッド**: findActiveIdsByFolder()
- **事前条件**: 同一folderIdに`result-1`・`result-2`をinsert済み。
- **入力値・テスト条件**: `result-2`を`markDeleted()`で論理削除する。
- **操作手順**: `findActiveIdsByFolder(db, 'folder-1', userId: userId)`を呼ぶ。
- **期待結果**: `['result-1']`のみが返る。

### テストケース13: 他ユーザーの成績が存在する場合、そのidは含まれない
- **カテゴリ**: 異常系
- **対象メソッド**: findActiveIdsByFolder()
- **事前条件**: `other-user`名義の`result-1`（folder-1）をinsert済み。
- **入力値・テスト条件**: `userId`（自ユーザー）を指定して`findActiveIdsByFolder()`を呼ぶ。
- **操作手順**: `findActiveIdsByFolder(db, 'folder-1', userId: userId)`を呼ぶ。
- **期待結果**: 空リストが返る。

### テストケース14: 未登録の成績をsaveした場合、新規レコードとして挿入される
- **カテゴリ**: 正常系
- **対象メソッド**: save()
- **事前条件**: DBが空の状態。
- **入力値・テスト条件**: `Database`インスタンスを直接渡して`save(db, result, userId: userId)`を呼ぶ（トランザクション内で使う経路の確認）。
- **操作手順**: `save()`実行後`findByUserId()`で確認する。
- **期待結果**: 新規レコードとして取得できる。

### テストケース15: 既存IDの成績をsaveした場合、レコードが置き換えられる（重複せず1件のまま）
- **カテゴリ**: 正常系
- **対象メソッド**: save()
- **事前条件**: `result-1`を`save()`済み。
- **入力値・テスト条件**: 同じIDで`totalCount`/`correctCount`を変更した内容を再度`save()`する。
- **操作手順**: `save()`実行後`findByUserId()`で全件取得する。
- **期待結果**: レコード数は1件のまま、内容が新しい値に置き換わっている。

### テストケース16: 存在する成績をmarkDeletedした場合、deletedAtとupdatedAtに指定時刻が入りpendingになる
- **カテゴリ**: 正常系
- **対象メソッド**: markDeleted()
- **事前条件**: `result-1`をinsert済み。
- **入力値・テスト条件**: `markDeleted(db, 'result-1', deletedAt)`を呼ぶ。
- **操作手順**: `markDeleted()`実行後、テーブルを直接`query()`して`deletedAt`/`updatedAt`/`syncStatus`列を確認する。
- **期待結果**: `syncStatus`が`pending`になり、`deletedAt`・`updatedAt`とも指定した`deletedAt`をUTC ISO8601変換した値になる。
