---
feature: 設定の読み書き（オンライン・オフライン共通）
prefix: STG
status: approved
targets:
  - lib/infrastructure/repositories/settings_repository_impl.dart
updated: 2026-09-27
---

# 設定の読み書き 振る舞い仕様書

## 1. 機能概要

`SettingsRepository` の契約。設定はユーザーごとに1件で、削除はしない。
読み取りはローカルだけから行い、変更はローカルに保存してキューに積む。
送信は同期の仕様書（`online_offline.md`、SYN）で扱う。

## 2. データ定義

### 2.1 UserSettings

| 項目 | 型 | 説明 |
|------|----|------|
| colorTheme | String | カラーテーマ。既定値「indigo」 |
| darkMode | bool | ダークモード。既定値 false |
| updatedAt | DateTime? | 最後に変更した時刻。一度も変更していなければ null |

ローカルの行は、このほかに userId・syncStatus を持つ（`online_offline.md` 2.1）。deletedAt は持たない。

### 2.2 入力ルール

該当なし（選べる値は設定画面の仕様書で定める）。

---

## 3. 画面仕様

該当なし。

## 4. 状態管理仕様

該当なし。

---

## 5. リポジトリ契約（SettingsRepository）

特に書かない限り、ユーザー U のデータを U として操作する。
「キューが1件増える」は、U の設定を指す U の項目がキューの末尾に増えることを表す。

| ID | メソッド | 条件 | 期待される結果 | 根拠 | 確定度 |
|----|----------|------|----------------|------|--------|
| STG-R01 | getSettings | ローカルに U の設定がない | 戻り値が `Right` で、カラーテーマ「indigo」・ダークモード false | 要件 §6-5 | 確定 |
| STG-R02 | getSettings | ローカルに U の設定（カラーテーマ「teal」・ダークモード true）がある | 戻り値が `Right` で、カラーテーマ「teal」・ダークモード true | 概要 §基本方針 | 確定 |
| STG-R03 | getSettings | ローカルに U の設定がなく、ユーザー V の設定（カラーテーマ「pink」）がある | 戻り値が `Right` で、カラーテーマ「indigo」 | 原則-9 | 確定 |
| STG-R04 | getSettings | オフラインで、ローカルに U の設定（カラーテーマ「teal」）がある | 戻り値が `Right` で、カラーテーマ「teal」 | 概要 §基本方針 | 確定 |
| STG-R05 | getSettings | ローカルの読み取りが失敗した | 戻り値が `Left(UnknownFailure)` | 概要 §登録・編集・削除の結果 | 確定 |
| STG-U01 | updateSettings | オンラインで、U の設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」・ダークモード true に変更した | 戻り値が `Right(unit)`。その後の `getSettings` がカラーテーマ「teal」・ダークモード true で、updatedAt が変更前の updatedAt より後。キューが1件増える | 概要 §基本方針 | 確定 |
| STG-U02 | updateSettings | オフラインで、U の設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」に変更した | 戻り値が `Right(unit)`。その後の `getSettings` のカラーテーマが「teal」。キューが1件増える | 概要 §基本方針 | 確定 |
| STG-U03 | updateSettings | ローカルに U の設定がない状態で、カラーテーマ「teal」に変更した | 戻り値が `Right(unit)`。その後の `getSettings` のカラーテーマが「teal」で、updatedAt が null でない。キューが1件増える | 概要 §基本方針 | 確定 |
| STG-U04 | updateSettings | U の設定（カラーテーマ「indigo」）の変更で、ローカルへの保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getSettings` のカラーテーマが「indigo」のまま。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| STG-U05 | updateSettings | U の設定（カラーテーマ「indigo」）の変更で、保存は成功しキューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getSettings` のカラーテーマが「indigo」のまま | 概要 §基本方針 | 確定 |
| STG-U06 | updateSettings | U の設定（カラーテーマ「indigo」・ダークモード false）がある状態で、同じ値で変更した | 戻り値が `Right(unit)`。updatedAt が変更前の updatedAt より後。キューが1件増える | 概要 §基本方針 | 確定 |
| STG-U07 | updateSettings | 変更した直後（送信前） | ローカルの U の設定の syncStatus が `pending` | 概要 §データの持ち方 | 確定 |
| STG-U08 | updateSettings | U の設定とユーザー V の設定（カラーテーマ「pink」）がある状態で、U の設定をカラーテーマ「teal」に変更した | V の設定のカラーテーマが「pink」のまま | 原則-9 | 確定 |

## 6. ユースケース

該当なし（Repository の契約だけを定める）。

---

## 7. 対象外

- **設定の削除**: 機能がないため（概要 §データの持ち方）
- **`NetworkFailure` / `AuthFailure`**: 読み取り・変更はリモートと通信しないため発生しない（概要 §登録・編集・削除の結果）
- **`NotFoundFailure`**: 設定がなければ既定値を返し（STG-R01）、変更では新しく作る（STG-U03）ため発生しない
- **BGM の設定**: 未実装のため（要件 §6-5）
- **送信・取得**: `online_offline.md` で扱う

## 8. 要確認事項

なし。

---

## 9. 網羅表

### 9.1 概要設計書との対応

| 概要設計書（§見出し：要点） | 仕様 ID ／ 振り分け |
|---------------------------|--------------------|
| §基本方針：読み取りはローカルだけ | STG-R02, STG-R04 |
| §基本方針：変更はオン・オフで同じ流れ | STG-U01, STG-U02 |
| §基本方針：保存とキュー登録は同じトランザクション | STG-U05 |
| §データの持ち方：設定は1件で削除しない | 7章 |
| §データの持ち方：変更直後は pending | STG-U07 |
| §登録・編集・削除の結果：成功 | STG-U01 |
| §登録・編集・削除の結果：UnknownFailure（どちらも保存しない） | STG-U04, STG-U05 |
| §登録・編集・削除の結果：NotFound / Network / Auth | 7章 |

### 9.2 操作 × 観点

| 操作 | 成功 | Unknown | NotFound | Network | Auth | キャンセル | 外側タップ | 処理中（無効化） | 二重操作 | 対象の不在 | 同じ値 | 入力の境界 |
|-----|-----|---------|----------|---------|------|-----------|-----------|----------------|---------|-----------|--------|-----------|
| getSettings | R02, R04 | R05 | 7章 | 7章 | 7章 | — 画面なし | — | — | — 読み取りのみ | R01（設定がない） | — | — |
| updateSettings | U01, U02 | U04, U05 | 7章 | 7章 | 7章 | — 画面なし | — | — 画面で扱う | — 画面で扱う | U03（設定がない） | U06 | — 画面で定める |

### 9.3 操作 × 共通原則

画面に関する原則（原則-2〜8, 10, 11）は画面の仕様書で扱う。

| 操作 | 原則-1（失敗してもデータを消さない） | 原則-9（自分のデータだけ） | 原則-2〜8, 10, 11 |
|-----|------------------------------------|---------------------------|-----------------|
| getSettings | — 読み取りのみ | STG-R03 | — 画面なし |
| updateSettings | STG-U04 | STG-U08 | — 画面なし |
