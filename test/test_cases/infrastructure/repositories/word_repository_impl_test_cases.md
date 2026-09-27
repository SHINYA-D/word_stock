## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/word_repository_impl.dart |
| クラス名 | WordRepositoryImpl |
| テスト対象メソッド | getWords() / createWord() / updateWord() / deleteWord() |
| 仕様書 | docs/detailed_design/online_offline/word_repository.md |

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | Fに未削除の単語「A」「B」と削除済みの単語「C」がある状態でFを指定した場合、戻り値がRightで「A」「B」を含み「C」を含まない [WRD-R01] | WRD-R01 #012871 | 正常系 | getWords() | ✅ |
| 2 | Fに単語「A」、別のフォルダGに単語「D」がある状態でFを指定した場合、戻り値がRightで「A」を含み「D」を含まない [WRD-R02] | WRD-R02 #552692 | 正常系 | getWords() | ✅ |
| 3 | FにUの単語「A」と、ユーザーVの単語「E」の行がある状態でFを指定した場合、戻り値がRightで「A」を含み「E」を含まない [WRD-R03] | WRD-R03 #efeaf3 | 正常系 | getWords() | ✅ |
| 4 | オフラインで、Fに単語「A」がある状態でFを指定した場合、戻り値がRightで「A」を含む [WRD-R04] | WRD-R04 #7e2470 | 正常系 | getWords() | ✅ |
| 5 | ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [WRD-R05] | WRD-R05 #193c04 | 異常系 | getWords() | ✅ |
| 6 | 削除済みのフォルダG（配下の単語もフォルダの削除に連動して削除済み）を指定した場合、戻り値がRight([]) [WRD-R06] | WRD-R06 #7a1479 | 境界値 | getWords() | ✅ |
| 7 | ローカルに存在しないフォルダのidを指定した場合、戻り値がRight([]) [WRD-R07] | WRD-R07 #f5b8ff | 境界値 | getWords() | ✅ |
| 8 | オンラインで、Fに表「apple」・裏「りんご」で登録した場合、戻り値がRightで表「apple」・裏「りんご」、createdAtとupdatedAtが等しい。その後のgetWords（F）に含まれる。キューが1件増える [WRD-C01] | WRD-C01 #0094d3 | 正常系 | createWord() | ✅ |
| 9 | オフラインで、Fに表「apple」・裏「りんご」で登録した場合、戻り値がRight。その後のgetWords（F）に含まれる。キューが1件増える [WRD-C02] | WRD-C02 #cb72ff | 正常系 | createWord() | ✅ |
| 10 | ローカルへの単語の保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）に含まれない。キューの件数が変わらない [WRD-C03] | WRD-C03 #06a335 | 異常系 | createWord() | ✅ |
| 11 | 単語の保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）に含まれない。キューの件数が変わらない [WRD-C04] | WRD-C04 #82293d | 異常系 | createWord() | ✅ |
| 12 | Fに表「2024-01-01」・裏「元日」で登録した場合、その後のgetWords（F）の単語の表が文字列「2024-01-01」 [WRD-C05] | WRD-C05 #301018 | 境界値 | createWord() | ✅ |
| 13 | 登録した直後（送信前）は、ローカルのその単語のsyncStatusがpending、deletedAtがnull [WRD-C06] | WRD-C06 #e6ac1a | 正常系 | createWord() | ✅ |
| 14 | 削除済みのフォルダGを指定して登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-C07] | WRD-C07 #b5585d | 異常系 | createWord() | ✅ |
| 15 | オンラインで、単語W（表「A」）を表「B」に編集した場合、戻り値がRightで表が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。その後のgetWords（F）のWの表が「B」。キューが1件増える [WRD-U01] | WRD-U01 #df271b | 正常系 | updateWord() | ✅ |
| 16 | オフラインで、単語W（表「A」）を表「B」に編集した場合、戻り値がRightで表が「B」。その後のgetWords（F）のWの表が「B」。キューが1件増える [WRD-U02] | WRD-U02 #0f5906 | 正常系 | updateWord() | ✅ |
| 17 | ローカルに存在しないidを指定して編集した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-U03] | WRD-U03 #b5c480 | 異常系 | updateWord() | ✅ |
| 18 | 削除済みの単語Wを指定して編集した場合、戻り値がLeft(NotFoundFailure)。その後のgetWords（F）にWが含まれない。キューの件数が変わらない [WRD-U04] | WRD-U04 #7ff2be | 異常系 | updateWord() | ✅ |
| 19 | 単語W（表「A」）の編集で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）のWの表が「A」のまま。キューの件数が変わらない [WRD-U05] | WRD-U05 #43e22a | 異常系 | updateWord() | ✅ |
| 20 | 単語W（表「A」・裏「a」）を、同じ表「A」・裏「a」で編集した場合、戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える [WRD-U06] | WRD-U06 #e57761 | 境界値 | updateWord() | ✅ |
| 21 | ユーザーVの単語Eのidを指定して、Uとして編集した場合、戻り値がLeft(NotFoundFailure)。Eの表は変わらない [WRD-U07] | WRD-U07 #1bd7ff | 異常系 | updateWord() | ✅ |
| 22 | 単語Wの編集で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）のWが編集前のまま [WRD-U08] | WRD-U08 #716e4e | 異常系 | updateWord() | ✅ |
| 23 | オンラインで、単語Wを削除した場合、戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。ローカルのWのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える [WRD-X01] | WRD-X01 #249992 | 正常系 | deleteWord() | ✅ |
| 24 | オフラインで、単語Wを削除した場合、戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。キューが1件増える [WRD-X02] | WRD-X02 #419ff6 | 正常系 | deleteWord() | ✅ |
| 25 | ローカルに存在しないidを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-X03] | WRD-X03 #c292b0 | 異常系 | deleteWord() | ✅ |
| 26 | 削除済みの単語Wを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-X04] | WRD-X04 #efd930 | 異常系 | deleteWord() | ✅ |
| 27 | 単語Wの削除で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）にWが含まれる。キューの件数が変わらない [WRD-X05] | WRD-X05 #6ab649 | 異常系 | deleteWord() | ✅ |
| 28 | ユーザーVの単語Eのidを指定して、Uとして削除した場合、戻り値がLeft(NotFoundFailure)。EのdeletedAtはnullのまま [WRD-X06] | WRD-X06 #71c79a | 異常系 | deleteWord() | ✅ |
| 29 | 単語Wの削除で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）にWが含まれる [WRD-X07] | WRD-X07 #1c55c8 | 異常系 | deleteWord() | ✅ |

## テストケース詳細

### テストケース1: Fに未削除の単語「A」「B」と削除済みの単語「C」がある状態でFを指定した場合、戻り値がRightで「A」「B」を含み「C」を含まない [WRD-R01]
- **カテゴリ**: 正常系
- **対象メソッド**: getWords()
- **事前条件**: フォルダFがローカルにある。Fに未削除の単語「A」「B」と論理削除済みの単語「C」がある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `getWords(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRightで、単語一覧に「A」「B」を含み「C」を含まない

### テストケース2: Fに単語「A」、別のフォルダGに単語「D」がある状態でFを指定した場合、戻り値がRightで「A」を含み「D」を含まない [WRD-R02]
- **カテゴリ**: 正常系
- **対象メソッド**: getWords()
- **事前条件**: フォルダF・Gがローカルにある。Fに単語「A」、Gに単語「D」がある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `getWords(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRightで、「A」を含み「D」を含まない

### テストケース3: FにUの単語「A」と、ユーザーVの単語「E」の行がある状態でFを指定した場合、戻り値がRightで「A」を含み「E」を含まない [WRD-R03]
- **カテゴリ**: 正常系
- **対象メソッド**: getWords()
- **事前条件**: フォルダFに、ユーザーUの単語「A」とユーザーVの単語「E」の行がある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `getWords(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRightで、「A」を含み「E」を含まない

### テストケース4: オフラインで、Fに単語「A」がある状態でFを指定した場合、戻り値がRightで「A」を含む [WRD-R04]
- **カテゴリ**: 正常系
- **対象メソッド**: getWords()
- **事前条件**: 接続状態がオフライン。フォルダFに単語「A」がある（本Repositoryは接続状態に依存しない設計のため、結果は接続状態に関わらず同じになることを確かめる）
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `getWords(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRightで、「A」を含む

### テストケース5: ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [WRD-R05]
- **カテゴリ**: 異常系
- **対象メソッド**: getWords()
- **事前条件**: `WordLocalDataSource.findByFolderId` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `getWords(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)

### テストケース6: 削除済みのフォルダG（配下の単語もフォルダの削除に連動して削除済み）を指定した場合、戻り値がRight([]) [WRD-R06]
- **カテゴリ**: 境界値
- **対象メソッド**: getWords()
- **事前条件**: フォルダGとその配下の単語Wが、いずれも論理削除済み
- **入力値・テスト条件**: userId=U, folderId='G'
- **操作手順**: `getWords(userId: U, folderId: 'G')` を呼ぶ
- **期待結果**: 戻り値がRight([])

### テストケース7: ローカルに存在しないフォルダのidを指定した場合、戻り値がRight([]) [WRD-R07]
- **カテゴリ**: 境界値
- **対象メソッド**: getWords()
- **事前条件**: なし
- **入力値・テスト条件**: userId=U, folderId='not-exist'
- **操作手順**: `getWords(userId: U, folderId: 'not-exist')` を呼ぶ
- **期待結果**: 戻り値がRight([])

### テストケース8: オンラインで、Fに表「apple」・裏「りんご」で登録した場合、戻り値がRightで表「apple」・裏「りんご」、createdAtとupdatedAtが等しい。その後のgetWords（F）に含まれる。キューが1件増える [WRD-C01]
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()
- **事前条件**: 接続状態がオンライン。未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', front='apple', back='りんご'
- **操作手順**: `createWord(userId: U, folderId: 'F', front: 'apple', back: 'りんご')` を呼び、その後 `getWords` とキューの件数を確認する
- **期待結果**: 戻り値がRightで、表「apple」・裏「りんご」、createdAtとupdatedAtが等しい。その後のgetWords（F）に含まれる。ユーザーUのキューが1件増える

### テストケース9: オフラインで、Fに表「apple」・裏「りんご」で登録した場合、戻り値がRight。その後のgetWords（F）に含まれる。キューが1件増える [WRD-C02]
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はWRD-C01と同じになることを確かめる）。未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', front='apple', back='りんご'
- **操作手順**: `createWord(userId: U, folderId: 'F', front: 'apple', back: 'りんご')` を呼ぶ
- **期待結果**: 戻り値がRight。その後のgetWords（F）に含まれる。キューが1件増える

### テストケース10: ローカルへの単語の保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）に含まれない。キューの件数が変わらない [WRD-C03]
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()
- **事前条件**: 未削除のフォルダFがローカルにある。`WordLocalDataSource.save` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', front='apple', back='りんご'
- **操作手順**: `createWord(userId: U, folderId: 'F', front: 'apple', back: 'りんご')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後のFの単語一覧に「apple」という表の単語が含まれない。ユーザーUのキューの件数が0のまま

### テストケース11: 単語の保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）に含まれない。キューの件数が変わらない [WRD-C04]
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()
- **事前条件**: 未削除のフォルダFがローカルにある。`SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', front='apple', back='りんご'
- **操作手順**: `createWord(userId: U, folderId: 'F', front: 'apple', back: 'りんご')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、単語の保存もキューへの登録も残らない（一覧に「apple」が含まれず、キューの件数が0のまま）

### テストケース12: Fに表「2024-01-01」・裏「元日」で登録した場合、その後のgetWords（F）の単語の表が文字列「2024-01-01」 [WRD-C05]
- **カテゴリ**: 境界値
- **対象メソッド**: createWord()
- **事前条件**: 未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', front='2024-01-01', back='元日'
- **操作手順**: `createWord(userId: U, folderId: 'F', front: '2024-01-01', back: '元日')` を呼び、その後 `getWords` を確認する
- **期待結果**: getWords（F）の単語の表が日時として解釈・変換されず、文字列「2024-01-01」のまま

### テストケース13: 登録した直後（送信前）は、ローカルのその単語のsyncStatusがpending、deletedAtがnull [WRD-C06]
- **カテゴリ**: 正常系
- **対象メソッド**: createWord()
- **事前条件**: 未削除のフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', front='apple', back='りんご'
- **操作手順**: `createWord(userId: U, folderId: 'F', front: 'apple', back: 'りんご')` を呼び、直後にローカルの行を直接参照する
- **期待結果**: ローカルの行のsyncStatusが`pending`、deletedAtがnull

### テストケース14: 削除済みのフォルダGを指定して登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-C07]
- **カテゴリ**: 異常系
- **対象メソッド**: createWord()
- **事前条件**: フォルダGが論理削除済み
- **入力値・テスト条件**: userId=U, folderId='G', front='apple', back='りんご'
- **操作手順**: `createWord(userId: U, folderId: 'G', front: 'apple', back: 'りんご')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース15: オンラインで、単語W（表「A」）を表「B」に編集した場合、戻り値がRightで表が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。その後のgetWords（F）のWの表が「B」。キューが1件増える [WRD-U01]
- **カテゴリ**: 正常系
- **対象メソッド**: updateWord()
- **事前条件**: 接続状態がオンライン。フォルダFに単語W（表「A」）がある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W', front='B', back='a'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'W', front: 'B', back: 'a')` を呼び、その後 `getWords` とキューの件数を確認する
- **期待結果**: 戻り値がRightで、表が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。その後のgetWords（F）のWの表が「B」。キューが1件増える

### テストケース16: オフラインで、単語W（表「A」）を表「B」に編集した場合、戻り値がRightで表が「B」。その後のgetWords（F）のWの表が「B」。キューが1件増える [WRD-U02]
- **カテゴリ**: 正常系
- **対象メソッド**: updateWord()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はWRD-U01と同じになることを確かめる）。フォルダFに単語W（表「A」）がある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W', front='B', back='back'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'W', front: 'B', back: 'back')` を呼ぶ
- **期待結果**: 戻り値がRightで、表が「B」。その後のgetWords（F）のWの表が「B」。キューが1件増える

### テストケース17: ローカルに存在しないidを指定して編集した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-U03]
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()
- **事前条件**: フォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='not-exist', front='B', back='b'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'not-exist', front: 'B', back: 'b')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース18: 削除済みの単語Wを指定して編集した場合、戻り値がLeft(NotFoundFailure)。その後のgetWords（F）にWが含まれない。キューの件数が変わらない [WRD-U04]
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()
- **事前条件**: フォルダFに単語W（表「A」）があり、論理削除済み
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W', front='B', back='b'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'W', front: 'B', back: 'b')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。その後のgetWords（F）にWが含まれない。キューの件数が変わらない

### テストケース19: 単語W（表「A」）の編集で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）のWの表が「A」のまま。キューの件数が変わらない [WRD-U05]
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()
- **事前条件**: フォルダFに単語W（表「A」）がある。`WordLocalDataSource.save` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W', front='B', back='b'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'W', front: 'B', back: 'b')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後のWの表が「A」のまま。キューの件数が変わらない

### テストケース20: 単語W（表「A」・裏「a」）を、同じ表「A」・裏「a」で編集した場合、戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える [WRD-U06]
- **カテゴリ**: 境界値
- **対象メソッド**: updateWord()
- **事前条件**: フォルダFに単語W（表「A」・裏「a」）がある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W', front='A', back='a'（編集前と同じ値）
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'W', front: 'A', back: 'a')` を呼ぶ
- **期待結果**: 戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える

### テストケース21: ユーザーVの単語Eのidを指定して、Uとして編集した場合、戻り値がLeft(NotFoundFailure)。Eの表は変わらない [WRD-U07]
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()
- **事前条件**: フォルダFに、ユーザーVの単語E（表「A」）がある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='E', front='B', back='b'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'E', front: 'B', back: 'b')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。Eの表は変わらない

### テストケース22: 単語Wの編集で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）のWが編集前のまま [WRD-U08]
- **カテゴリ**: 異常系
- **対象メソッド**: updateWord()
- **事前条件**: フォルダFに単語W（表「A」）がある。`SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W', front='B', back='b'
- **操作手順**: `updateWord(userId: U, folderId: 'F', wordId: 'W', front: 'B', back: 'b')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、その後のgetWords（F）のWが編集前のまま

### テストケース23: オンラインで、単語Wを削除した場合、戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。ローカルのWのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える [WRD-X01]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteWord()
- **事前条件**: 接続状態がオンライン。フォルダFに単語Wがある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'W')` を呼び、その後 `getWords` とローカルの行、キューの件数を確認する
- **期待結果**: 戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。ローカルのWのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える

### テストケース24: オフラインで、単語Wを削除した場合、戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。キューが1件増える [WRD-X02]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteWord()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はWRD-X01と同じになることを確かめる）。フォルダFに単語Wがある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'W')` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。その後のgetWords（F）にWが含まれない。キューが1件増える

### テストケース25: ローカルに存在しないidを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-X03]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()
- **事前条件**: フォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='not-exist'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'not-exist')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース26: 削除済みの単語Wを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [WRD-X04]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()
- **事前条件**: フォルダFに単語Wがあり、論理削除済み
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'W')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース27: 単語Wの削除で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）にWが含まれる。キューの件数が変わらない [WRD-X05]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()
- **事前条件**: フォルダFに単語Wがある。`WordLocalDataSource.markDeleted` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'W')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後のgetWords（F）にWが含まれる。キューの件数が変わらない

### テストケース28: ユーザーVの単語Eのidを指定して、Uとして削除した場合、戻り値がLeft(NotFoundFailure)。EのdeletedAtはnullのまま [WRD-X06]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()
- **事前条件**: フォルダFに、ユーザーVの単語Eがある
- **入力値・テスト条件**: userId=U, folderId='F', wordId='E'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'E')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。EのdeletedAtはnullのまま

### テストケース29: 単語Wの削除で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetWords（F）にWが含まれる [WRD-X07]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteWord()
- **事前条件**: フォルダFに単語Wがある。`SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', wordId='W'
- **操作手順**: `deleteWord(userId: U, folderId: 'F', wordId: 'W')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、その後のgetWords（F）にWが含まれる
