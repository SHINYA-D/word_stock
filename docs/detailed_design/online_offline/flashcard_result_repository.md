---
feature: 成績の読み書き（オンライン・オフライン共通）
prefix: FRS
status: approved
targets:
  - lib/infrastructure/repositories/flashcard_result_repository_impl.dart
updated: 2026-09-27
---

# 成績の読み書き 振る舞い仕様書

## 1. 機能概要

`FlashcardResultRepository` の契約。読み取りはローカルだけから行い、登録はローカルに保存してキューに積む。
成績は登録だけで、編集はしない。削除はフォルダの削除に連動するときだけ行う（`folder_repository.md` FLD-X03）。
送信は同期の仕様書（`online_offline.md`、SYN）で扱う。

## 2. データ定義

### 2.1 FlashcardResult

| 項目 | 型 | 説明 |
|------|----|------|
| id | String | 成績の id |
| folderId | String | テストしたフォルダの id |
| totalCount | int | 問題数 |
| correctCount | int | 正解数 |
| date | DateTime | テストした時刻 |
| updatedAt | DateTime | 最後に変更した時刻 |

ローカルの行は、このほかに userId・deletedAt・syncStatus を持つ（`online_offline.md` 2.1）。

### 2.2 入力ルール

該当なし（問題数・正解数はテスト画面が数えた値をそのまま保存する）。

---

## 3. 画面仕様

該当なし。

## 4. 状態管理仕様

該当なし。

---

## 5. リポジトリ契約（FlashcardResultRepository）

特に書かない限り、ユーザー U のデータを U として操作する。
`getFlashcardResults` はフォルダで絞り込まず、U の未削除の成績をすべて返す（フォルダ別の表示は画面の仕様書で定める）。
「キューが1件増える」は、その成績の id を指す U の項目がキューの末尾に増えることを表す。

| ID | メソッド | 条件 | 期待される結果 | 根拠 | 確定度 |
|----|----------|------|----------------|------|--------|
| FRS-R01 | getFlashcardResults | ローカルに未削除の成績 R1・R2 と削除済みの成績 R3 がある | 戻り値が `Right` で、R1・R2 を含み R3 を含まない | 概要 §論理削除 | 確定 |
| FRS-R02 | getFlashcardResults | ローカルに U の成績 R1 とユーザー V の成績 R4 がある | 戻り値が `Right` で、R1 を含み R4 を含まない | 原則-9 | 確定 |
| FRS-R03 | getFlashcardResults | オフラインで、ローカルに成績 R1 がある | 戻り値が `Right` で、R1 を含む | 概要 §基本方針 | 確定 |
| FRS-R04 | getFlashcardResults | ローカルの読み取りが失敗した | 戻り値が `Left(UnknownFailure)` | 概要 §登録・編集・削除の結果 | 確定 |
| FRS-C01 | saveFlashcardResult | オンラインで、フォルダ F・問題数10・正解数7で登録した | 戻り値が `Right` で、フォルダ F・問題数10・正解数7、date と updatedAt が等しい。その後の `getFlashcardResults` に含まれる。キューが1件増える | 概要 §基本方針 | 確定 |
| FRS-C02 | saveFlashcardResult | オフラインで、フォルダ F・問題数10・正解数7で登録した | 戻り値が `Right`。その後の `getFlashcardResults` に含まれる。キューが1件増える | 概要 §基本方針 | 確定 |
| FRS-C03 | saveFlashcardResult | ローカルへの成績の保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getFlashcardResults` に含まれない。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| FRS-C04 | saveFlashcardResult | 成績の保存は成功し、キューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getFlashcardResults` に含まれない。キューの件数が変わらない | 概要 §基本方針 | 確定 |
| FRS-C05 | saveFlashcardResult | 登録した直後（送信前） | ローカルのその成績の syncStatus が `pending`、deletedAt が null | 概要 §データの持ち方 | 確定 |
| FRS-C06 | saveFlashcardResult | フォルダ F・問題数10・正解数7で2回登録した | 戻り値の id が2回で異なる。その後の `getFlashcardResults` に2件とも含まれる。キューが2件増える | 要件 §6-4 | 確定 |
| FRS-C07 | saveFlashcardResult | 削除済みのフォルダ G を指定して登録した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §論理削除, ユーザー決定 2026-09-27 | 確定 |
| FRS-R05 | getFlashcardResults | フォルダ F の成績 R1 と、別のフォルダ G の成績 R2 がある | 戻り値が `Right` で、R1・R2 の両方を含む | 要件 §6-4 | 確定 |

## 6. ユースケース

該当なし（Repository の契約だけを定める）。

---

## 7. 対象外

- **成績の編集・個別の削除**: 機能がないため（要件 §6-4）。フォルダの削除に連動する削除は FLD-X03 で扱う
- **`NetworkFailure` / `AuthFailure`**: 登録・読み取りはリモートと通信しないため発生しない（概要 §登録・編集・削除の結果）
- **`getFlashcardResults` の `NotFoundFailure`**: 一覧の取得で対象の不在は起きない（0件なら空の一覧を返す）
- **`saveFlashcardResult` の原則-9**: 登録は常にログイン中のユーザーのデータとして保存するため、他のユーザーのデータに触れる経路がない
- **送信・取得**: `online_offline.md` で扱う
- **正答率の計算**: エンティティの独自ロジックで、この仕様書の範囲外

## 8. 要確認事項

| ID | 論点 | 案 | 推奨 | 決定 |
|----|------|----|------|------|
| FRS-C07 | 削除済み・存在しないフォルダを指定して `saveFlashcardResult` した場合の結果。概要設計書に記述がない（テスト中に別の端末でフォルダが削除され、取得で反映された場合に起こりうる） | A: `Left(NotFoundFailure)` を返す ／ B: そのまま登録する | A（FLD-C07・WRD-C07 とそろえる。削除済みのフォルダに、画面から見えない成績が残るのを防ぐ） | 決定: 案A（2026-09-27） |

---

## 9. 網羅表

### 9.1 概要設計書との対応

| 概要設計書（§見出し：要点） | 仕様 ID ／ 振り分け |
|---------------------------|--------------------|
| §基本方針：読み取りはローカルだけ | FRS-R01, FRS-R03, FRS-R05 |
| §基本方針：登録はオン・オフで同じ流れ | FRS-C01, FRS-C02 |
| §基本方針：保存とキュー登録は同じトランザクション | FRS-C04 |
| §データの持ち方：成績は登録のみ | 7章 |
| §データの持ち方：登録直後は pending・未削除 | FRS-C05 |
| §論理削除：読み取りで削除済みを返さない | FRS-R01 |
| §登録・編集・削除の結果：成功 | FRS-C01 |
| §登録・編集・削除の結果：UnknownFailure（どちらも保存しない） | FRS-C03, FRS-C04 |
| §登録・編集・削除の結果：NotFound | FRS-C07（8章） |
| §登録・編集・削除の結果：Network / Auth | 7章 |

### 9.2 操作 × 観点

| 操作 | 成功 | Unknown | NotFound | Network | Auth | キャンセル | 外側タップ | 処理中（無効化） | 二重操作 | 対象の不在 | 同じ値 | 入力の境界 |
|-----|-----|---------|----------|---------|------|-----------|-----------|----------------|---------|-----------|--------|-----------|
| getFlashcardResults | R01, R03, R05 | R04 | 7章 | 7章 | 7章 | — 画面なし | — | — | — 読み取りのみ | — 一覧 | — | — |
| saveFlashcardResult | C01, C02, C05 | C03, C04 | C07（8章） | 7章 | 7章 | — 画面なし | — | — 画面で扱う | — 画面で扱う | C07（削除済みのフォルダ） | C06（同じ内容を2回） | — 画面が数えた値 |

### 9.3 操作 × 共通原則

画面に関する原則（原則-2〜8, 10, 11）は画面の仕様書で扱う。

| 操作 | 原則-1（失敗してもデータを消さない） | 原則-9（自分のデータだけ） | 原則-2〜8, 10, 11 |
|-----|------------------------------------|---------------------------|-----------------|
| getFlashcardResults | — 読み取りのみ | FRS-R02 | — 画面なし |
| saveFlashcardResult | FRS-C03 | 7章 | — 画面なし |
