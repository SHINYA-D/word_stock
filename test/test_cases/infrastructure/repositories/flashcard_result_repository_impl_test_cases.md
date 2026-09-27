## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/flashcard_result_repository_impl.dart |
| クラス名 | FlashcardResultRepositoryImpl |
| テスト対象メソッド | getFlashcardResults() / saveFlashcardResult() |
| 仕様書 | docs/detailed_design/online_offline/flashcard_result_repository.md |

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | ローカルに未削除の成績「R1」「R2」と削除済みの成績「R3」がある場合、戻り値がRightで「R1」「R2」を含み「R3」を含まない [FRS-R01] | FRS-R01 #eefa53 | 正常系 | getFlashcardResults() | ✅ |
| 2 | ローカルにUの成績「R1」と、ユーザーVの成績「R4」がある場合、戻り値がRightで「R1」を含み「R4」を含まない [FRS-R02] | FRS-R02 #a70258 | 正常系 | getFlashcardResults() | ✅ |
| 3 | オフラインで、ローカルに成績「R1」がある場合、戻り値がRightで「R1」を含む [FRS-R03] | FRS-R03 #899799 | 正常系 | getFlashcardResults() | ✅ |
| 4 | ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [FRS-R04] | FRS-R04 #c3e4e2 | 異常系 | getFlashcardResults() | ✅ |
| 5 | フォルダFの成績「R1」と、別のフォルダGの成績「R2」がある場合、戻り値がRightで「R1」「R2」の両方を含む [FRS-R05] | FRS-R05 #fa0741 | 境界値 | getFlashcardResults() | ✅ |
| 6 | オンラインで、フォルダFに問題数10・正解数7で登録した場合、戻り値がRightでフォルダF・問題数10・正解数7、dateとupdatedAtが等しい。その後のgetFlashcardResultsに含まれる。キューが1件増える [FRS-C01] | FRS-C01 #ebc054 | 正常系 | saveFlashcardResult() | ✅ |
| 7 | オフラインで、フォルダFに問題数10・正解数7で登録した場合、戻り値がRight。その後のgetFlashcardResultsに含まれる。キューが1件増える [FRS-C02] | FRS-C02 #5e876f | 正常系 | saveFlashcardResult() | ✅ |
| 8 | ローカルへの成績の保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFlashcardResultsに含まれない。キューの件数が変わらない [FRS-C03] | FRS-C03 #358bb3 | 異常系 | saveFlashcardResult() | ✅ |
| 9 | 成績の保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFlashcardResultsに含まれない。キューの件数が変わらない [FRS-C04] | FRS-C04 #104b14 | 異常系 | saveFlashcardResult() | ✅ |
| 10 | 登録した直後（送信前）は、ローカルのその成績のsyncStatusがpending、deletedAtがnull [FRS-C05] | FRS-C05 #b25f20 | 正常系 | saveFlashcardResult() | ✅ |
| 11 | フォルダFに問題数10・正解数7で2回登録した場合、戻り値のidが2回で異なる。その後のgetFlashcardResultsに2件とも含まれる。キューが2件増える [FRS-C06] | FRS-C06 #9f99fb | 境界値 | saveFlashcardResult() | ✅ |
| 12 | 削除済みのフォルダGを指定して登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FRS-C07] | FRS-C07 #c297a7 | 異常系 | saveFlashcardResult() | ✅ |

## テストケース詳細

### テストケース1: ローカルに未削除の成績「R1」「R2」と削除済みの成績「R3」がある場合、戻り値がRightで「R1」「R2」を含み「R3」を含まない [FRS-R01]
- **カテゴリ**: 正常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: フォルダFがローカルにある。Fに未削除の成績「R1」「R2」と論理削除済みの成績「R3」がある
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFlashcardResults(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、「R1」「R2」を含み「R3」を含まない

### テストケース2: ローカルにUの成績「R1」と、ユーザーVの成績「R4」がある場合、戻り値がRightで「R1」を含み「R4」を含まない [FRS-R02]
- **カテゴリ**: 正常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: フォルダFに、ユーザーUの成績「R1」とユーザーVの成績「R4」の行がある
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFlashcardResults(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、「R1」を含み「R4」を含まない

### テストケース3: オフラインで、ローカルに成績「R1」がある場合、戻り値がRightで「R1」を含む [FRS-R03]
- **カテゴリ**: 正常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: 接続状態がオフライン。ローカルに成績「R1」がある（本Repositoryは接続状態に依存しない設計のため、結果は接続状態に関わらず同じになることを確かめる）
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFlashcardResults(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、「R1」を含む

### テストケース4: ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [FRS-R04]
- **カテゴリ**: 異常系
- **対象メソッド**: getFlashcardResults()
- **事前条件**: `FlashcardResultLocalDataSource.findByUserId` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFlashcardResults(userId: U)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)

### テストケース5: フォルダFの成績「R1」と、別のフォルダGの成績「R2」がある場合、戻り値がRightで「R1」「R2」の両方を含む [FRS-R05]
- **カテゴリ**: 境界値
- **対象メソッド**: getFlashcardResults()
- **事前条件**: フォルダF・Gがローカルにある。Fに成績「R1」、Gに成績「R2」がある
- **入力値・テスト条件**: userId=U（folderId は指定しない）
- **操作手順**: `getFlashcardResults(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、フォルダで絞り込まれず「R1」「R2」の両方を含む

### テストケース6: オンラインで、フォルダFに問題数10・正解数7で登録した場合、戻り値がRightでフォルダF・問題数10・正解数7、dateとupdatedAtが等しい。その後のgetFlashcardResultsに含まれる。キューが1件増える [FRS-C01]
- **カテゴリ**: 正常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: 接続状態がオンライン。未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', totalCount=10, correctCount=7
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'F', totalCount: 10, correctCount: 7)` を呼び、その後 `getFlashcardResults` とキューの件数を確認する
- **期待結果**: 戻り値がRightで、フォルダF・問題数10・正解数7、dateとupdatedAtが等しい。その後のgetFlashcardResultsに含まれる。ユーザーUのキューが1件増える

### テストケース7: オフラインで、フォルダFに問題数10・正解数7で登録した場合、戻り値がRight。その後のgetFlashcardResultsに含まれる。キューが1件増える [FRS-C02]
- **カテゴリ**: 正常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はFRS-C01と同じになることを確かめる）。未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', totalCount=10, correctCount=7
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'F', totalCount: 10, correctCount: 7)` を呼ぶ
- **期待結果**: 戻り値がRight。その後のgetFlashcardResultsに含まれる。キューが1件増える

### テストケース8: ローカルへの成績の保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFlashcardResultsに含まれない。キューの件数が変わらない [FRS-C03]
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: 未削除のフォルダFがローカルにある。`FlashcardResultLocalDataSource.save` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', totalCount=10, correctCount=7
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'F', totalCount: 10, correctCount: 7)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後のUの成績一覧に含まれない。ユーザーUのキューの件数が0のまま

### テストケース9: 成績の保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFlashcardResultsに含まれない。キューの件数が変わらない [FRS-C04]
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: 未削除のフォルダFがローカルにある。`SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', totalCount=10, correctCount=7
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'F', totalCount: 10, correctCount: 7)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、成績の保存もキューへの登録も残らない（一覧に含まれず、キューの件数が0のまま）

### テストケース10: 登録した直後（送信前）は、ローカルのその成績のsyncStatusがpending、deletedAtがnull [FRS-C05]
- **カテゴリ**: 正常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: 未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', totalCount=10, correctCount=7
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'F', totalCount: 10, correctCount: 7)` を呼び、直後にローカルの行を直接参照する
- **期待結果**: ローカルの行のsyncStatusが`pending`、deletedAtがnull

### テストケース11: フォルダFに問題数10・正解数7で2回登録した場合、戻り値のidが2回で異なる。その後のgetFlashcardResultsに2件とも含まれる。キューが2件増える [FRS-C06]
- **カテゴリ**: 境界値
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: 未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', totalCount=10, correctCount=7（同じ内容で2回呼ぶ）
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'F', totalCount: 10, correctCount: 7)` を2回呼ぶ
- **期待結果**: 戻り値のidが2回で異なる。その後のgetFlashcardResultsに2件とも含まれる。ユーザーUのキューが2件増える

### テストケース12: 削除済みのフォルダGを指定して登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FRS-C07]
- **カテゴリ**: 異常系
- **対象メソッド**: saveFlashcardResult()
- **事前条件**: フォルダGが論理削除済み
- **入力値・テスト条件**: userId=U, folderId='G', totalCount=10, correctCount=7
- **操作手順**: `saveFlashcardResult(userId: U, folderId: 'G', totalCount: 10, correctCount: 7)` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない
