---
feature: 単語の読み書き（オンライン・オフライン共通）
prefix: WRD
status: approved
targets:
  - lib/infrastructure/repositories/word_repository_impl.dart
updated: 2026-09-27
---

# 単語の読み書き 振る舞い仕様書

## 1. 機能概要

`WordRepository` の契約。読み取りはローカルだけから行い、登録・編集・削除はローカルに保存してキューに積む。
オンライン・オフラインで結果は変わらない。送信は同期の仕様書（`online_offline.md`、SYN）で扱う。

## 2. データ定義

### 2.1 Word

| 項目 | 型 | 説明 |
|------|----|------|
| id | String | 単語の id |
| front | String | 表（単語） |
| back | String | 裏（意味） |
| createdAt | DateTime | 登録した時刻 |
| updatedAt | DateTime | 最後に変更した時刻 |

ローカルの行は、このほかに folderId・userId・deletedAt・syncStatus を持つ（`online_offline.md` 2.1）。

### 2.2 入力ルール

該当なし（表・裏の入力ルールは画面の仕様書で定める）。

---

## 3. 画面仕様

該当なし。

## 4. 状態管理仕様

該当なし。

---

## 5. リポジトリ契約（WordRepository）

特に書かない限り、ユーザー U のデータを U として操作し、単語はフォルダ F の中にある。
「キューが1件増える」は、その単語の id と親フォルダ F の id を指す U の項目がキューの末尾に増えることを表す。

| ID | メソッド | 条件 | 期待される結果 | 根拠 | 確定度 |
|----|----------|------|----------------|------|--------|
| WRD-R01 | getWords | F に未削除の単語「A」「B」と削除済みの単語「C」がある状態で F を指定した | 戻り値が `Right` で、「A」「B」を含み「C」を含まない | 概要 §論理削除 | 確定 |
| WRD-R02 | getWords | F に単語「A」、別のフォルダ G に単語「D」がある状態で F を指定した | 戻り値が `Right` で、「A」を含み「D」を含まない | 要件 §6-2 | 確定 |
| WRD-R03 | getWords | F に U の単語「A」と、ユーザー V の単語「E」の行がある状態で F を指定した | 戻り値が `Right` で、「A」を含み「E」を含まない | 原則-9 | 確定 |
| WRD-R04 | getWords | オフラインで、F に単語「A」がある状態で F を指定した | 戻り値が `Right` で、「A」を含む | 概要 §基本方針 | 確定 |
| WRD-R05 | getWords | ローカルの読み取りが失敗した | 戻り値が `Left(UnknownFailure)` | 概要 §登録・編集・削除の結果 | 確定 |
| WRD-R06 | getWords | 削除済みのフォルダ G（配下の単語もフォルダの削除に連動して削除済み）を指定した | 戻り値が `Right([])` | 概要 §論理削除 | 確定 |
| WRD-R07 | getWords | ローカルに存在しないフォルダの id を指定した | 戻り値が `Right([])` | 概要 §基本方針 | 確定 |
| WRD-C01 | createWord | オンラインで、F に表「apple」・裏「りんご」で登録した | 戻り値が `Right` で、表「apple」・裏「りんご」、createdAt と updatedAt が等しい。その後の `getWords`（F）に含まれる。キューが1件増える | 概要 §基本方針 | 確定 |
| WRD-C02 | createWord | オフラインで、F に表「apple」・裏「りんご」で登録した | 戻り値が `Right`。その後の `getWords`（F）に含まれる。キューが1件増える | 概要 §基本方針 | 確定 |
| WRD-C03 | createWord | ローカルへの単語の保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getWords`（F）に含まれない。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| WRD-C04 | createWord | 単語の保存は成功し、キューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getWords`（F）に含まれない。キューの件数が変わらない | 概要 §基本方針 | 確定 |
| WRD-C05 | createWord | F に表「2024-01-01」・裏「元日」で登録した | その後の `getWords`（F）の単語の表が文字列「2024-01-01」 | 概要 §キュー | 確定 |
| WRD-C06 | createWord | 登録した直後（送信前） | ローカルのその単語の syncStatus が `pending`、deletedAt が null | 概要 §データの持ち方 | 確定 |
| WRD-C07 | createWord | 削除済みのフォルダ G を指定して登録した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §論理削除, ユーザー決定 2026-09-27 | 確定 |
| WRD-U01 | updateWord | オンラインで、単語 W（表「A」）を表「B」に編集した | 戻り値が `Right` で、表が「B」、createdAt が編集前と等しく、updatedAt が編集前の updatedAt より後。その後の `getWords`（F）の W の表が「B」。キューが1件増える | 概要 §基本方針 | 確定 |
| WRD-U02 | updateWord | オフラインで、単語 W（表「A」）を表「B」に編集した | 戻り値が `Right` で、表が「B」。その後の `getWords`（F）の W の表が「B」。キューが1件増える | 概要 §基本方針 | 確定 |
| WRD-U03 | updateWord | ローカルに存在しない id を指定して編集した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| WRD-U04 | updateWord | 削除済みの単語 W を指定して編集した | 戻り値が `Left(NotFoundFailure)`。その後の `getWords`（F）に W が含まれない。キューの件数が変わらない | 概要 §論理削除 | 確定 |
| WRD-U05 | updateWord | 単語 W（表「A」）の編集で、ローカルへの保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getWords`（F）の W の表が「A」のまま。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| WRD-U06 | updateWord | 単語 W（表「A」・裏「a」）を、同じ表「A」・裏「a」で編集した | 戻り値が `Right` で、updatedAt が編集前の updatedAt より後。キューが1件増える | 概要 §基本方針 | 確定 |
| WRD-U07 | updateWord | ユーザー V の単語 E の id を指定して、U として編集した | 戻り値が `Left(NotFoundFailure)`。E の表は変わらない | 原則-9 | 確定 |
| WRD-U08 | updateWord | 単語 W の編集で、保存は成功しキューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getWords`（F）の W が編集前のまま | 概要 §基本方針 | 確定 |
| WRD-X01 | deleteWord | オンラインで、単語 W を削除した | 戻り値が `Right(unit)`。その後の `getWords`（F）に W が含まれない。ローカルの W の deletedAt が入り、updatedAt が削除前の updatedAt より後。キューが1件増える | 概要 §論理削除 | 確定 |
| WRD-X02 | deleteWord | オフラインで、単語 W を削除した | 戻り値が `Right(unit)`。その後の `getWords`（F）に W が含まれない。キューが1件増える | 概要 §基本方針 | 確定 |
| WRD-X03 | deleteWord | ローカルに存在しない id を指定して削除した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| WRD-X04 | deleteWord | 削除済みの単語 W を指定して削除した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §論理削除 | 確定 |
| WRD-X05 | deleteWord | 単語 W の削除で、ローカルへの保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getWords`（F）に W が含まれる。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| WRD-X06 | deleteWord | ユーザー V の単語 E の id を指定して、U として削除した | 戻り値が `Left(NotFoundFailure)`。E の deletedAt は null のまま | 原則-9 | 確定 |
| WRD-X07 | deleteWord | 単語 W の削除で、保存は成功しキューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getWords`（F）に W が含まれる | 概要 §基本方針 | 確定 |

## 6. ユースケース

該当なし（Repository の契約だけを定める）。

---

## 7. 対象外

- **`NetworkFailure` / `AuthFailure`**: 登録・編集・削除・読み取りはリモートと通信しないため発生しない（概要 §登録・編集・削除の結果）
- **`getWords` の `NotFoundFailure`**: 一覧の取得は、フォルダが削除済み・存在しない場合も空の一覧を返す（WRD-R06・R07）ため発生しない
- **`createWord` の原則-9**: 登録は常にログイン中のユーザーのデータとして保存するため、他のユーザーのデータに触れる経路がない
- **単語のフォルダ間の移動**: 機能がないため
- **送信・取得**: `online_offline.md` で扱う
- **一覧の並び順・検索**: 画面の仕様書で定める

## 8. 要確認事項

| ID | 論点 | 案 | 推奨 | 決定 |
|----|------|----|------|------|
| WRD-C07 | 削除済み・存在しないフォルダを指定して `createWord` した場合の結果。概要設計書に記述がない | A: `Left(NotFoundFailure)` を返す ／ B: そのまま登録する | A（削除済みのフォルダの中に、画面から見えない単語ができるのを防ぐ。FLD-C07 とそろえる） | 決定: 案A（2026-09-27） |

---

## 9. 網羅表

### 9.1 概要設計書との対応

| 概要設計書（§見出し：要点） | 仕様 ID ／ 振り分け |
|---------------------------|--------------------|
| §基本方針：読み取りはローカルだけ | WRD-R01, WRD-R04 |
| §基本方針：登録・編集・削除はオン・オフで同じ流れ | WRD-C01/C02, WRD-U01/U02, WRD-X01/X02 |
| §基本方針：保存とキュー登録は同じトランザクション | WRD-C04, WRD-U08, WRD-X07 |
| §データの持ち方：登録直後は pending・未削除 | WRD-C06 |
| §論理削除：削除は deletedAt を入れる | WRD-X01 |
| §論理削除：読み取りで削除済みを返さない | WRD-R01 |
| §論理削除：削除済みは編集・削除の対象にしない | WRD-U04, WRD-X04 |
| §キュー：日時を推測しない | WRD-C05 |
| §登録・編集・削除の結果：成功 | WRD-C01, WRD-U01, WRD-X01 |
| §登録・編集・削除の結果：NotFoundFailure | WRD-U03, WRD-U04, WRD-X03, WRD-X04 |
| §登録・編集・削除の結果：UnknownFailure（どちらも保存しない） | WRD-C03, WRD-C04, WRD-U05, WRD-U08, WRD-X05, WRD-X07 |
| §登録・編集・削除の結果：Network/Auth は起きない | 7章 |

### 9.2 操作 × 観点

| 操作 | 成功 | Unknown | NotFound | Network | Auth | キャンセル | 外側タップ | 処理中（無効化） | 二重操作 | 対象の不在 | 同じ値 | 入力の境界 |
|-----|-----|---------|----------|---------|------|-----------|-----------|----------------|---------|-----------|--------|-----------|
| getWords | R01, R04 | R05 | 7章 | 7章 | 7章 | — 画面なし | — | — | — 読み取りのみ | R06, R07（フォルダが削除済み・存在しない） | — | — |
| createWord | C01, C02, C06 | C03, C04 | C07（8章） | 7章 | 7章 | — 画面なし | — | — 画面で扱う | — 画面で扱う（原則-4） | — 対象なし | — 同じ内容の可否は画面で定める | C05（日時に見える文字列） |
| updateWord | U01, U02 | U05, U08 | U03, U04, U07 | 7章 | 7章 | — | — | — | — | U03, U04 | U06 | — |
| deleteWord | X01, X02 | X05, X07 | X03, X04, X06 | 7章 | 7章 | — | — | — | — | X03, X04 | — 削除に値はない | — |

### 9.3 操作 × 共通原則

画面に関する原則（原則-2〜8, 10, 11）は画面の仕様書で扱う。

| 操作 | 原則-1（失敗してもデータを消さない） | 原則-9（自分のデータだけ） | 原則-2〜8, 10, 11 |
|-----|------------------------------------|---------------------------|-----------------|
| getWords | — 読み取りのみ | WRD-R03 | — 画面なし |
| createWord | WRD-C03 | 7章 | — 画面なし |
| updateWord | WRD-U05 | WRD-U07 | — 画面なし |
| deleteWord | WRD-X05 | WRD-X06 | — 画面なし |
