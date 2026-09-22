# mock_sample_repository_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/mock/mock_sample_repository.dart |
| クラス名 | MockSampleRepository |
| テスト対象メソッド | getSamples() / createSample() / updateSample() / deleteSample() |
| 仕様書 | docs/detailed_design/presentation/sample/sample_page.md |

## 実行環境について

`MockSampleRepository` はインメモリの Map で状態を持つのみで、外部依存（SQLite / Firestore /
ネットワーク）を持たない。`SampleRepository` の実装がこの Mock しかないため、例外的に契約テストの
対象にしている（`mock/` 配下は限定分母外のため、ハーネスはカバレッジではなく green のみで判定する）。

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | u1に「A」「B」がある場合、Right([A, B])が作成順で返る | SMP-R01 | 正常系 | getSamples() | ✅ |
| 2 | u1にサンプルがない場合、Right([])が返る | SMP-R02 | 境界値 | getSamples() | ✅ |
| 3 | u1に「A」、u2に「B」がある状態でuserId「u2」で取得した場合、Right([B])が返る | SMP-R03 | 正常系 | getSamples() | ✅ |
| 4 | u1に「A」がある状態でuserId「u1」・name「B」で作成した場合、Right(Sample)が返りnameは「B」、idは空でない、createdAtとupdatedAtが等しい。その後のgetSamples(u1)はRight([A, B]) | SMP-R04 | 正常系 | createSample() | ✅ |
| 5 | userId「u1」・name「B」で2回作成した場合、2回の戻り値のidが異なる。その後のgetSamples(u1)は名前「B」の要素を2つ含む | SMP-R05 | 境界値 | createSample() | ✅ |
| 6 | u1に「A」がある状態でuserId「u2」・name「B」で作成した場合、その後のgetSamples(u1)はRight([A])のまま | SMP-R06 | 正常系 | createSample() | ✅ |
| 7 | u1に「A」「B」がある状態でuserId「u1」・sampleId「Aのid」・name「C」で変更した場合、Right(Sample)が返り、idはAのid、nameは「C」、createdAtはAのcreatedAtと等しい、updatedAtはAのupdatedAtより後。その後のgetSamples(u1)はRight([C, B]) | SMP-R07 | 正常系 | updateSample() | ✅ |
| 8 | u1に「A」がある状態で、存在しないsampleIdで変更した場合、Left(NotFoundFailure)。その後のgetSamples(u1)はRight([A])のまま | SMP-R08 | 異常系 | updateSample() | ✅ |
| 9 | u2に「B」がある状態でuserId「u1」・sampleId「Bのid」・name「C」で変更した場合、Left(NotFoundFailure)。その後のgetSamples(u2)はRight([B])のまま | SMP-R09 | 異常系 | updateSample() | ✅ |
| 10 | u1に「A」「B」がある状態でuserId「u1」・sampleId「Aのid」で削除した場合、Right(unit)。その後のgetSamples(u1)はRight([B]) | SMP-R10 | 正常系 | deleteSample() | ✅ |
| 11 | u1に「A」がある状態で、存在しないsampleIdで削除した場合、Right(unit)。その後のgetSamples(u1)はRight([A])のまま | SMP-R11 | 境界値 | deleteSample() | ✅ |
| 12 | u2に「B」がある状態でuserId「u1」・sampleId「Bのid」で削除した場合、Right(unit)。その後のgetSamples(u2)はRight([B])のまま | SMP-R12 | 正常系 | deleteSample() | ✅ |

## テストケース詳細

### テストケース1: u1に「A」「B」がある場合、Right([A, B])が作成順で返る
- **カテゴリ**: 正常系
- **対象メソッド**: getSamples()
- **事前条件**: u1に「A」を先に作成し、続けて「B」を作成する
- **入力値・テスト条件**: userId="u1"
- **操作手順**: `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Right([A, B])`（作成順） [SMP-R01]

### テストケース2: u1にサンプルがない場合、Right([])が返る
- **カテゴリ**: 境界値
- **対象メソッド**: getSamples()
- **事前条件**: u1に何も作成していない
- **入力値・テスト条件**: userId="u1"
- **操作手順**: `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Right([])` [SMP-R02]

### テストケース3: u1に「A」、u2に「B」がある状態でuserId「u2」で取得した場合、Right([B])が返る
- **カテゴリ**: 正常系
- **対象メソッド**: getSamples()
- **事前条件**: u1に「A」、u2に「B」を作成する
- **入力値・テスト条件**: userId="u2"
- **操作手順**: `getSamples(userId: "u2")` を呼ぶ
- **期待結果**: `Right([B])` [SMP-R03]

### テストケース4: u1に「A」がある状態でuserId「u1」・name「B」で作成した場合、Right(Sample)が返りnameは「B」、idは空でない、createdAtとupdatedAtが等しい。その後のgetSamples(u1)はRight([A, B])
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: u1に「A」を作成済み
- **入力値・テスト条件**: userId="u1", name="B"
- **操作手順**: `createSample(userId: "u1", name: "B")` を呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Right(Sample)` が返り、name は「B」、id は空でない、createdAt と updatedAt が等しい。その後の getSamples(u1) は `Right([A, B])` [SMP-R04]

### テストケース5: userId「u1」・name「B」で2回作成した場合、2回の戻り値のidが異なる。その後のgetSamples(u1)は名前「B」の要素を2つ含む
- **カテゴリ**: 境界値
- **対象メソッド**: createSample()
- **事前条件**: u1に何も作成していない
- **入力値・テスト条件**: userId="u1", name="B" を2回
- **操作手順**: `createSample(userId: "u1", name: "B")` を2回呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: 2回の戻り値の id が異なる。その後の getSamples(u1) は名前「B」の要素を2つ含む [SMP-R05]

### テストケース6: u1に「A」がある状態でuserId「u2」・name「B」で作成した場合、その後のgetSamples(u1)はRight([A])のまま
- **カテゴリ**: 正常系
- **対象メソッド**: createSample()
- **事前条件**: u1に「A」を作成済み
- **入力値・テスト条件**: userId="u2", name="B"
- **操作手順**: `createSample(userId: "u2", name: "B")` を呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: その後の getSamples(u1) は `Right([A])` のまま [SMP-R06]

### テストケース7: u1に「A」「B」がある状態でuserId「u1」・sampleId「Aのid」・name「C」で変更した場合、Right(Sample)が返り、idはAのid、nameは「C」、createdAtはAのcreatedAtと等しい、updatedAtはAのupdatedAtより後。その後のgetSamples(u1)はRight([C, B])
- **カテゴリ**: 正常系
- **対象メソッド**: updateSample()
- **事前条件**: u1に「A」「B」がこの順で作成済み
- **入力値・テスト条件**: userId="u1", sampleId=Aのid, name="C"
- **操作手順**: `updateSample(userId: "u1", sampleId: A.id, name: "C")` を呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Right(Sample)` が返り、id は A の id、name は「C」、createdAt は A の createdAt と等しい、updatedAt は A の updatedAt より後。その後の getSamples(u1) は `Right([C, B])` [SMP-R07]

### テストケース8: u1に「A」がある状態で、存在しないsampleIdで変更した場合、Left(NotFoundFailure)。その後のgetSamples(u1)はRight([A])のまま
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: u1に「A」を作成済み
- **入力値・テスト条件**: userId="u1", sampleId="not-exist", name="C"
- **操作手順**: `updateSample(userId: "u1", sampleId: "not-exist", name: "C")` を呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Left(NotFoundFailure)`。その後の getSamples(u1) は `Right([A])` のまま [SMP-R08]

### テストケース9: u2に「B」がある状態でuserId「u1」・sampleId「Bのid」・name「C」で変更した場合、Left(NotFoundFailure)。その後のgetSamples(u2)はRight([B])のまま
- **カテゴリ**: 異常系
- **対象メソッド**: updateSample()
- **事前条件**: u2に「B」を作成済み
- **入力値・テスト条件**: userId="u1", sampleId=Bのid, name="C"
- **操作手順**: `updateSample(userId: "u1", sampleId: B.id, name: "C")` を呼び、続けて `getSamples(userId: "u2")` を呼ぶ
- **期待結果**: `Left(NotFoundFailure)`。その後の getSamples(u2) は `Right([B])` のまま [SMP-R09]

### テストケース10: u1に「A」「B」がある状態でuserId「u1」・sampleId「Aのid」で削除した場合、Right(unit)。その後のgetSamples(u1)はRight([B])
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: u1に「A」「B」がこの順で作成済み
- **入力値・テスト条件**: userId="u1", sampleId=Aのid
- **操作手順**: `deleteSample(userId: "u1", sampleId: A.id)` を呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Right(unit)`。その後の getSamples(u1) は `Right([B])` [SMP-R10]

### テストケース11: u1に「A」がある状態で、存在しないsampleIdで削除した場合、Right(unit)。その後のgetSamples(u1)はRight([A])のまま
- **カテゴリ**: 境界値
- **対象メソッド**: deleteSample()
- **事前条件**: u1に「A」を作成済み
- **入力値・テスト条件**: userId="u1", sampleId="not-exist"
- **操作手順**: `deleteSample(userId: "u1", sampleId: "not-exist")` を呼び、続けて `getSamples(userId: "u1")` を呼ぶ
- **期待結果**: `Right(unit)`。その後の getSamples(u1) は `Right([A])` のまま [SMP-R11]

### テストケース12: u2に「B」がある状態でuserId「u1」・sampleId「Bのid」で削除した場合、Right(unit)。その後のgetSamples(u2)はRight([B])のまま
- **カテゴリ**: 正常系
- **対象メソッド**: deleteSample()
- **事前条件**: u2に「B」を作成済み
- **入力値・テスト条件**: userId="u1", sampleId=Bのid
- **操作手順**: `deleteSample(userId: "u1", sampleId: B.id)` を呼び、続けて `getSamples(userId: "u2")` を呼ぶ
- **期待結果**: `Right(unit)`。その後の getSamples(u2) は `Right([B])` のまま [SMP-R12]

## 対象外

- L12-27：コンストラクタが用意する既定データ（`mock-user-id` の初期サンプル2件）。仕様書は userId
  「u1」「u2」を使う契約テストのみを定めており、既定データの内容自体は仕様の対象外
