# flashcard_result_local_data_source_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/data_sources/local/flashcard_result_local_data_source.dart |
| クラス名 | FlashcardResultLocalDataSource |
| テスト対象メソッド | delete()（新規追加分）、insert() / findByUserId()（deleteの前提として補助的に確認） |

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
