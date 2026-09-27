---
feature: フォルダの読み書き（オンライン・オフライン共通）
prefix: FLD
status: approved
targets:
  - lib/infrastructure/repositories/folder_repository_impl.dart
updated: 2026-09-27
---

# フォルダの読み書き 振る舞い仕様書

## 1. 機能概要

`FolderRepository` の契約。読み取りはローカルだけから行い、登録・編集・削除はローカルに保存してキューに積む。
オンライン・オフラインで結果は変わらない。送信は同期の仕様書（`online_offline.md`、SYN）で扱う。

## 2. データ定義

### 2.1 Folder

| 項目 | 型 | 説明 |
|------|----|------|
| id | String | フォルダの id |
| name | String | フォルダ名 |
| parentFolderId | String? | 親フォルダの id。null ならルート |
| createdAt | DateTime | 登録した時刻 |
| updatedAt | DateTime | 最後に変更した時刻 |

ローカルの行は、このほかに userId・deletedAt・syncStatus を持つ（`online_offline.md` 2.1）。

### 2.2 入力ルール

該当なし（フォルダ名の入力ルールは画面の仕様書で定める）。

---

## 3. 画面仕様

該当なし。

## 4. 状態管理仕様

該当なし。

---

## 5. リポジトリ契約（FolderRepository）

特に書かない限り、ユーザー U のデータを U として操作する。
「キューが1件増える」は、そのフォルダの id を指す U の項目がキューの末尾に増えることを表す。

| ID | メソッド | 条件 | 期待される結果 | 根拠 | 確定度 |
|----|----------|------|----------------|------|--------|
| FLD-R01 | getFolders | ローカルに未削除のフォルダ「A」「B」と削除済みのフォルダ「C」がある | 戻り値が `Right` で、「A」「B」を含み「C」を含まない | 概要 §論理削除 | 確定 |
| FLD-R02 | getFolders | ローカルに U のフォルダ「A」とユーザー V のフォルダ「D」がある | 戻り値が `Right` で、「A」を含み「D」を含まない | 原則-9 | 確定 |
| FLD-R03 | getFolders | オフラインで、ローカルにフォルダ「A」がある | 戻り値が `Right` で、「A」を含む | 概要 §基本方針 | 確定 |
| FLD-R04 | getFolders | ローカルの読み取りが失敗した | 戻り値が `Left(UnknownFailure)` | 概要 §登録・編集・削除の結果 | 確定 |
| FLD-C01 | createFolder | オンラインで、名前「A」で登録した | 戻り値が `Right` で、名前が「A」、createdAt と updatedAt が等しい。その後の `getFolders` に「A」が含まれる。キューが1件増える | 概要 §基本方針 | 確定 |
| FLD-C02 | createFolder | オフラインで、名前「A」で登録した | 戻り値が `Right` で、名前が「A」。その後の `getFolders` に「A」が含まれる。キューが1件増える | 概要 §基本方針 | 確定 |
| FLD-C03 | createFolder | ローカルへのフォルダの保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getFolders` に登録しようとしたフォルダが含まれない。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| FLD-C04 | createFolder | フォルダの保存は成功し、キューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getFolders` に登録しようとしたフォルダが含まれない。キューの件数が変わらない | 概要 §基本方針 | 確定 |
| FLD-C05 | createFolder | 親フォルダ G を指定して、名前「A」で登録した | 戻り値が `Right` で、parentFolderId が G の id | 要件 §6-2 | 確定 |
| FLD-C06 | createFolder | 登録した直後（送信前） | ローカルのそのフォルダの syncStatus が `pending`、deletedAt が null | 概要 §データの持ち方 | 確定 |
| FLD-C07 | createFolder | 削除済みのフォルダ G を親に指定して、名前「A」で登録した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §論理削除, ユーザー決定 2026-09-27 | 確定 |
| FLD-U01 | updateFolder | オンラインで、ローカルのフォルダ F（名前「A」）を名前「B」に編集した | 戻り値が `Right` で、名前が「B」、createdAt が編集前と等しく、updatedAt が編集前の updatedAt より後。その後の `getFolders` の F の名前が「B」。キューが1件増える | 概要 §基本方針 | 確定 |
| FLD-U02 | updateFolder | オフラインで、ローカルのフォルダ F（名前「A」）を名前「B」に編集した | 戻り値が `Right` で、名前が「B」。その後の `getFolders` の F の名前が「B」。キューが1件増える | 概要 §基本方針 | 確定 |
| FLD-U03 | updateFolder | ローカルに存在しない id を指定して編集した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| FLD-U04 | updateFolder | 削除済みのフォルダ F を指定して編集した | 戻り値が `Left(NotFoundFailure)`。その後の `getFolders` に F が含まれない。キューの件数が変わらない | 概要 §論理削除 | 確定 |
| FLD-U05 | updateFolder | ローカルのフォルダ F（名前「A」）の編集で、ローカルへの保存が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getFolders` の F の名前が「A」のまま。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| FLD-U06 | updateFolder | ローカルのフォルダ F（名前「A」）を、同じ名前「A」で編集した | 戻り値が `Right` で、updatedAt が編集前の updatedAt より後。キューが1件増える | 概要 §基本方針 | 確定 |
| FLD-U07 | updateFolder | ユーザー V のフォルダ G の id を指定して、U として編集した | 戻り値が `Left(NotFoundFailure)`。G の名前は変わらない | 原則-9 | 確定 |
| FLD-U08 | updateFolder | ローカルのフォルダ F の編集で、保存は成功しキューへの登録が失敗した | 戻り値が `Left(UnknownFailure)`。その後の `getFolders` の F の名前が編集前のまま | 概要 §基本方針 | 確定 |
| FLD-X01 | deleteFolder | オンラインで、ローカルのフォルダ F（配下なし）を削除した | 戻り値が `Right(unit)`。その後の `getFolders` に F が含まれない。ローカルの F の deletedAt が入り、updatedAt が削除前の updatedAt より後。キューが1件増える | 概要 §論理削除 | 確定 |
| FLD-X02 | deleteFolder | オフラインで、ローカルのフォルダ F（配下なし）を削除した | 戻り値が `Right(unit)`。その後の `getFolders` に F が含まれない。キューが1件増える | 概要 §基本方針 | 確定 |
| FLD-X03 | deleteFolder | フォルダ F に子フォルダ G、G に単語 W、F に成績 R がある状態で F を削除した | 戻り値が `Right(unit)`。ローカルの F・G・W・R の deletedAt がすべて入る。`getWords`（G）に W が含まれない。`getFlashcardResults` に R が含まれない。キューが4件（F・G・W・R）増える | 概要 §フォルダの削除 | 確定 |
| FLD-X04 | deleteFolder | FLD-X03 と同じ配下がある状態で F を削除した | ローカルの G・W・R の deletedAt が F の deletedAt と等しい | 概要 §フォルダの削除 | 確定 |
| FLD-X05 | deleteFolder | ローカルに存在しない id を指定して削除した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §登録・編集・削除の結果 | 確定 |
| FLD-X06 | deleteFolder | 削除済みのフォルダ F を指定して削除した | 戻り値が `Left(NotFoundFailure)`。キューの件数が変わらない | 概要 §論理削除 | 確定 |
| FLD-X07 | deleteFolder | FLD-X03 と同じ配下がある状態で F を削除し、配下の単語 W の保存が失敗した | 戻り値が `Left(UnknownFailure)`。ローカルの F・G・W・R の deletedAt がすべて null のまま。キューの件数が変わらない | 概要 §フォルダの削除 | 確定 |
| FLD-X08 | deleteFolder | ユーザー V のフォルダ G の id を指定して、U として削除した | 戻り値が `Left(NotFoundFailure)`。G の deletedAt は null のまま | 原則-9 | 確定 |
| FLD-X09 | deleteFolder | 削除済みの子フォルダ G（deletedAt が F の削除より前）を持つフォルダ F を削除した | ローカルの G の deletedAt が変わらない。キューが1件（F）増える | 概要 §論理削除 | 確定 |

## 6. ユースケース

該当なし（Repository の契約だけを定める）。

---

## 7. 対象外

- **`NetworkFailure` / `AuthFailure`**: 登録・編集・削除・読み取りはリモートと通信しないため発生しない（概要 §登録・編集・削除の結果）
- **`getFolders` の `NotFoundFailure`**: 一覧の取得で対象の不在は起きない（0件なら空の一覧を返す）
- **`createFolder` の原則-9**: 登録は常にログイン中のユーザーのデータとして保存するため、他のユーザーのデータに触れる経路がない
- **送信・取得**: `online_offline.md` で扱う
- **一覧の並び順・親フォルダでの絞り込み**: 画面の仕様書で定める

## 8. 要確認事項

| ID | 論点 | 案 | 推奨 | 決定 |
|----|------|----|------|------|
| FLD-C07 | 削除済み・存在しない親フォルダを指定して `createFolder` した場合の結果。概要設計書に記述がない | A: `Left(NotFoundFailure)` を返す ／ B: そのまま登録する | A（削除済みのフォルダの中に、画面から見えないフォルダができるのを防ぐ） | 決定: 案A（2026-09-27） |

---

## 9. 網羅表

### 9.1 概要設計書との対応

| 概要設計書（§見出し：要点） | 仕様 ID ／ 振り分け |
|---------------------------|--------------------|
| §基本方針：読み取りはローカルだけ | FLD-R01, FLD-R03 |
| §基本方針：登録・編集・削除はオン・オフで同じ流れ | FLD-C01/C02, FLD-U01/U02, FLD-X01/X02 |
| §基本方針：保存とキュー登録は同じトランザクション | FLD-C04, FLD-U08, FLD-X07 |
| §データの持ち方：登録直後は pending・未削除 | FLD-C06 |
| §論理削除：削除は deletedAt を入れる | FLD-X01 |
| §論理削除：読み取りで削除済みを返さない | FLD-R01 |
| §論理削除：削除済みは編集・削除の対象にしない | FLD-U04, FLD-X06 |
| §登録・編集・削除の結果：成功 | FLD-C01, FLD-U01, FLD-X01 |
| §登録・編集・削除の結果：NotFoundFailure | FLD-U03, FLD-U04, FLD-X05, FLD-X06 |
| §登録・編集・削除の結果：UnknownFailure（どちらも保存しない） | FLD-C03, FLD-C04, FLD-U05, FLD-U08, FLD-X07 |
| §登録・編集・削除の結果：Network/Auth は起きない | 7章 |
| §フォルダの削除：配下もすべて削除済み・1つのトランザクション | FLD-X03, FLD-X04, FLD-X07 |

### 9.2 操作 × 観点

| 操作 | 成功 | Unknown | NotFound | Network | Auth | キャンセル | 外側タップ | 処理中（無効化） | 二重操作 | 対象の不在 | 同じ値 | 入力の境界 |
|-----|-----|---------|----------|---------|------|-----------|-----------|----------------|---------|-----------|--------|-----------|
| getFolders | R01, R03 | R04 | 7章 | 7章 | 7章 | — 画面なし | — | — | — 読み取りのみ | — 一覧 | — | — |
| createFolder | C01, C02, C05, C06 | C03, C04 | C07（8章） | 7章 | 7章 | — 画面なし | — | — 画面で扱う | — 画面で扱う（原則-4） | — 対象なし | — 同じ名前の可否は画面で定める | — 画面で定める |
| updateFolder | U01, U02 | U05, U08 | U03, U04, U07 | 7章 | 7章 | — | — | — | — | U03, U04 | U06 | — |
| deleteFolder | X01, X02, X03 | X07 | X05, X06, X08 | 7章 | 7章 | — | — | — | — | X05, X06 | X09（配下に削除済みがある） | — |

### 9.3 操作 × 共通原則

画面に関する原則（原則-2〜8, 10, 11）は画面の仕様書で扱う。

| 操作 | 原則-1（失敗してもデータを消さない） | 原則-9（自分のデータだけ） | 原則-2〜8, 10, 11 |
|-----|------------------------------------|---------------------------|-----------------|
| getFolders | — 読み取りのみ | FLD-R02 | — 画面なし |
| createFolder | FLD-C03（既存の一覧に影響しない） | 7章（登録は常にログイン中のユーザーのデータ） | — 画面なし |
| updateFolder | FLD-U05 | FLD-U07 | — 画面なし |
| deleteFolder | FLD-X07 | FLD-X08 | — 画面なし |
