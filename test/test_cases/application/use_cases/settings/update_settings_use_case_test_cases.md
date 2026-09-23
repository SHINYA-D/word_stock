# update_settings_use_case_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/application/use_cases/settings/update_settings_use_case.dart |
| クラス名 | UpdateSettingsUseCase |
| テスト対象メソッド | call() |

## 実行環境について

`UpdateSettingsUseCase` は `SettingsRepository`（インターフェース）へ単純に委譲するだけで、
分岐や加工ロジックを持たない。手書きの `_FakeSettingsRepository`（`implements SettingsRepository`）
に差し込む戻り値を切り替え、引数（`userId` / `settings`）がそのまま渡ること・戻り値がそのまま
返ることのみを検証する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 正しい引数でRepositoryに委譲し、Rightがそのまま返る | 正常系 | call() | ✅ |
| 2 | Repositoryが失敗を返した場合、Leftがそのまま返る | 異常系 | call() | ✅ |

## テストケース詳細

### テストケース1: 正しい引数でRepositoryに委譲し、Rightがそのまま返る
- **カテゴリ**: 正常系
- **対象メソッド**: call()
- **事前条件**: `_FakeSettingsRepository.updateSettingsResult` に `Right(unit)` を設定。
- **入力値・テスト条件**: `userId: 'u1'`, `settings: UserSettings(colorTheme: 'teal', darkMode: false, updatedAt: ...)`
- **操作手順**: `UpdateSettingsUseCase(repository)(userId: 'u1', settings: settings)` を呼び出す。
- **期待結果**: `repository.capturedUserId` が `'u1'`、`repository.capturedSettings` が渡した `settings` と等しく、戻り値が `Right(unit)` とそのまま等しい。

### テストケース2: Repositoryが失敗を返した場合、Leftがそのまま返る
- **カテゴリ**: 異常系
- **対象メソッド**: call()
- **事前条件**: `_FakeSettingsRepository.updateSettingsResult` に `Left(Failure.unknown('e'))` を設定。
- **入力値・テスト条件**: `userId: 'u1'`, `settings: UserSettings(...)`
- **操作手順**: `UpdateSettingsUseCase(repository)(userId: 'u1', settings: settings)` を呼び出す。
- **期待結果**: 戻り値が `Left(Failure.unknown('e'))` とそのまま等しい。

## 対象外

分岐・加工ロジックが無いため対象外行なし（全行がテスト済み）。
