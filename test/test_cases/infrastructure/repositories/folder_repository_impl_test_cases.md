## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/folder_repository_impl.dart |
| クラス名 | FolderRepositoryImpl |
| テスト対象メソッド | getFolders() / createFolder() / updateFolder() / deleteFolder() |
| 仕様書 | docs/detailed_design/online_offline/folder_repository.md |

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | ローカルに未削除のフォルダ「A」「B」と削除済みのフォルダ「C」がある場合、戻り値がRightで「A」「B」を含み「C」を含まない [FLD-R01] | FLD-R01 #ebdcff | 正常系 | getFolders() | ✅ |
| 2 | ローカルにUのフォルダ「A」とユーザーVのフォルダ「D」がある場合、戻り値がRightで「A」を含み「D」を含まない [FLD-R02] | FLD-R02 #e7b829 | 正常系 | getFolders() | ✅ |
| 3 | オフラインで、ローカルにフォルダ「A」がある場合、戻り値がRightで「A」を含む [FLD-R03] | FLD-R03 #23dc00 | 正常系 | getFolders() | ✅ |
| 4 | ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [FLD-R04] | FLD-R04 #64bcaa | 異常系 | getFolders() | ✅ |
| 5 | オンラインで、名前「A」で登録した場合、戻り値がRightで名前が「A」、createdAtとupdatedAtが等しい。その後のgetFoldersに「A」が含まれる。キューが1件増える [FLD-C01] | FLD-C01 #0bd4fc | 正常系 | createFolder() | ✅ |
| 6 | オフラインで、名前「A」で登録した場合、戻り値がRightで名前が「A」。その後のgetFoldersに「A」が含まれる。キューが1件増える [FLD-C02] | FLD-C02 #82684c | 正常系 | createFolder() | ✅ |
| 7 | ローカルへのフォルダの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersに登録しようとしたフォルダが含まれない。キューの件数が変わらない [FLD-C03] | FLD-C03 #25a91c | 異常系 | createFolder() | ✅ |
| 8 | フォルダの保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersに登録しようとしたフォルダが含まれない。キューの件数が変わらない [FLD-C04] | FLD-C04 #45d72f | 異常系 | createFolder() | ✅ |
| 9 | 親フォルダGを指定して、名前「A」で登録した場合、戻り値がRightでparentFolderIdがGのid [FLD-C05] | FLD-C05 #4b46ba | 正常系 | createFolder() | ✅ |
| 10 | 登録した直後（送信前）は、ローカルのそのフォルダのsyncStatusがpending、deletedAtがnull [FLD-C06] | FLD-C06 #383b4a | 正常系 | createFolder() | ✅ |
| 11 | 削除済みのフォルダGを親に指定して、名前「A」で登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-C07] | FLD-C07 #b6ba26 | 異常系 | createFolder() | ✅ |
| 12 | オンラインで、ローカルのフォルダF（名前「A」）を名前「B」に編集した場合、戻り値がRightで名前が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。その後のgetFoldersのFの名前が「B」。キューが1件増える [FLD-U01] | FLD-U01 #1ad311 | 正常系 | updateFolder() | ✅ |
| 13 | オフラインで、ローカルのフォルダF（名前「A」）を名前「B」に編集した場合、戻り値がRightで名前が「B」。その後のgetFoldersのFの名前が「B」。キューが1件増える [FLD-U02] | FLD-U02 #0f1628 | 正常系 | updateFolder() | ✅ |
| 14 | ローカルに存在しないidを指定して編集した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-U03] | FLD-U03 #0d9ea4 | 異常系 | updateFolder() | ✅ |
| 15 | 削除済みのフォルダFを指定して編集した場合、戻り値がLeft(NotFoundFailure)。その後のgetFoldersにFが含まれない。キューの件数が変わらない [FLD-U04] | FLD-U04 #034e99 | 異常系 | updateFolder() | ✅ |
| 16 | ローカルのフォルダF（名前「A」）の編集で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersのFの名前が「A」のまま。キューの件数が変わらない [FLD-U05] | FLD-U05 #710733 | 異常系 | updateFolder() | ✅ |
| 17 | ローカルのフォルダF（名前「A」）を、同じ名前「A」で編集した場合、戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える [FLD-U06] | FLD-U06 #6e3770 | 境界値 | updateFolder() | ✅ |
| 18 | ユーザーVのフォルダGのidを指定して、Uとして編集した場合、戻り値がLeft(NotFoundFailure)。Gの名前は変わらない [FLD-U07] | FLD-U07 #13e2d3 | 異常系 | updateFolder() | ✅ |
| 19 | ローカルのフォルダFの編集で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersのFの名前が編集前のまま [FLD-U08] | FLD-U08 #ec8ff5 | 異常系 | updateFolder() | ✅ |
| 20 | オンラインで、ローカルのフォルダF（配下なし）を削除した場合、戻り値がRight(unit)。その後のgetFoldersにFが含まれない。ローカルのFのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える [FLD-X01] | FLD-X01 #124348 | 正常系 | deleteFolder() | ✅ |
| 21 | オフラインで、ローカルのフォルダF（配下なし）を削除した場合、戻り値がRight(unit)。その後のgetFoldersにFが含まれない。キューが1件増える [FLD-X02] | FLD-X02 #3f11d7 | 正常系 | deleteFolder() | ✅ |
| 22 | フォルダFに子フォルダG、Gに単語W、Fに成績Rがある状態でFを削除した場合、戻り値がRight(unit)。ローカルのF・G・W・Rのdeletedatがすべて入る。getWords（G）にWが含まれない。getFlashcardResultsにRが含まれない。キューが4件（F・G・W・R）増える [FLD-X03] | FLD-X03 #a17186 | 正常系 | deleteFolder() | ✅ |
| 23 | FLD-X03と同じ配下がある状態でFを削除した場合、ローカルのG・W・RのdeletedAtがFのdeletedAtと等しい [FLD-X04] | FLD-X04 #44767f | 正常系 | deleteFolder() | ✅ |
| 24 | ローカルに存在しないidを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-X05] | FLD-X05 #1d4dc3 | 異常系 | deleteFolder() | ✅ |
| 25 | 削除済みのフォルダFを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-X06] | FLD-X06 #fa5fad | 異常系 | deleteFolder() | ✅ |
| 26 | FLD-X03と同じ配下がある状態でFを削除し、配下の単語Wの保存が失敗した場合、戻り値がLeft(UnknownFailure)。ローカルのF・G・W・RのdeletedAtがすべてnullのまま。キューの件数が変わらない [FLD-X07] | FLD-X07 #b65acf | 異常系 | deleteFolder() | ✅ |
| 27 | ユーザーVのフォルダGのidを指定して、Uとして削除した場合、戻り値がLeft(NotFoundFailure)。GのdeletedAtはnullのまま [FLD-X08] | FLD-X08 #18cf9b | 異常系 | deleteFolder() | ✅ |
| 28 | 削除済みの子フォルダG（deletedAtがFの削除より前）を持つフォルダFを削除した場合、ローカルのGのdeletedAtが変わらない。キューが1件（F）増える [FLD-X09] | FLD-X09 #1c2e27 | 境界値 | deleteFolder() | ✅ |

## テストケース詳細

### テストケース1: ローカルに未削除のフォルダ「A」「B」と削除済みのフォルダ「C」がある場合、戻り値がRightで「A」「B」を含み「C」を含まない [FLD-R01]
- **カテゴリ**: 正常系
- **対象メソッド**: getFolders()
- **事前条件**: ユーザーUのローカルにフォルダ「A」「B」（未削除）と「C」（論理削除済み）がある
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFolders(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、フォルダの一覧に「A」「B」を含み「C」を含まない

### テストケース2: ローカルにUのフォルダ「A」とユーザーVのフォルダ「D」がある場合、戻り値がRightで「A」を含み「D」を含まない [FLD-R02]
- **カテゴリ**: 正常系
- **対象メソッド**: getFolders()
- **事前条件**: ユーザーUのフォルダ「A」とユーザーVのフォルダ「D」がローカルにある
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFolders(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、「A」を含み「D」を含まない

### テストケース3: オフラインで、ローカルにフォルダ「A」がある場合、戻り値がRightで「A」を含む [FLD-R03]
- **カテゴリ**: 正常系
- **対象メソッド**: getFolders()
- **事前条件**: 接続状態がオフライン。ローカルにフォルダ「A」がある（本Repositoryは接続状態に依存しない設計のため、結果は接続状態に関わらず同じになることを確かめる）
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFolders(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、「A」を含む

### テストケース4: ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [FLD-R04]
- **カテゴリ**: 異常系
- **対象メソッド**: getFolders()
- **事前条件**: `FolderLocalDataSource.findByUserId` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U
- **操作手順**: `getFolders(userId: U)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)

### テストケース5: オンラインで、名前「A」で登録した場合、戻り値がRightで名前が「A」、createdAtとupdatedAtが等しい。その後のgetFoldersに「A」が含まれる。キューが1件増える [FLD-C01]
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()
- **事前条件**: 接続状態がオンライン
- **入力値・テスト条件**: userId=U, name='A'
- **操作手順**: `createFolder(userId: U, name: 'A')` を呼び、その後 `getFolders(userId: U)` とキューの件数を確認する
- **期待結果**: 戻り値がRightで、名前が「A」、createdAtとupdatedAtが等しい。その後のgetFoldersに「A」が含まれる。ユーザーUのキューが1件増える

### テストケース6: オフラインで、名前「A」で登録した場合、戻り値がRightで名前が「A」。その後のgetFoldersに「A」が含まれる。キューが1件増える [FLD-C02]
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はFLD-C01と同じになることを確かめる）
- **入力値・テスト条件**: userId=U, name='A'
- **操作手順**: `createFolder(userId: U, name: 'A')` を呼び、その後 `getFolders(userId: U)` とキューの件数を確認する
- **期待結果**: 戻り値がRightで、名前が「A」。その後のgetFoldersに「A」が含まれる。キューが1件増える

### テストケース7: ローカルへのフォルダの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersに登録しようとしたフォルダが含まれない。キューの件数が変わらない [FLD-C03]
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder()
- **事前条件**: `FolderLocalDataSource.save` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, name='A'
- **操作手順**: `createFolder(userId: U, name: 'A')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後の一覧に「A」という名前のフォルダが含まれない。ユーザーUのキューの件数が0のまま

### テストケース8: フォルダの保存は成功し、キューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersに登録しようとしたフォルダが含まれない。キューの件数が変わらない [FLD-C04]
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder()
- **事前条件**: `SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, name='A'
- **操作手順**: `createFolder(userId: U, name: 'A')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、フォルダの保存もキューへの登録も残らない（一覧に「A」が含まれず、キューの件数が0のまま）

### テストケース9: 親フォルダGを指定して、名前「A」で登録した場合、戻り値がRightでparentFolderIdがGのid [FLD-C05]
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()
- **事前条件**: 未削除のフォルダGがローカルにある
- **入力値・テスト条件**: userId=U, name='A', parentFolderId='G'
- **操作手順**: `createFolder(userId: U, name: 'A', parentFolderId: 'G')` を呼ぶ
- **期待結果**: 戻り値がRightで、parentFolderIdが「G」

### テストケース10: 登録した直後（送信前）は、ローカルのそのフォルダのsyncStatusがpending、deletedAtがnull [FLD-C06]
- **カテゴリ**: 正常系
- **対象メソッド**: createFolder()
- **事前条件**: なし
- **入力値・テスト条件**: userId=U, name='A'
- **操作手順**: `createFolder(userId: U, name: 'A')` を呼び、直後にローカルの行を直接参照する
- **期待結果**: ローカルの行のsyncStatusが`pending`、deletedAtがnull

### テストケース11: 削除済みのフォルダGを親に指定して、名前「A」で登録した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-C07]
- **カテゴリ**: 異常系
- **対象メソッド**: createFolder()
- **事前条件**: フォルダGが論理削除済み
- **入力値・テスト条件**: userId=U, name='A', parentFolderId='G'
- **操作手順**: `createFolder(userId: U, name: 'A', parentFolderId: 'G')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース12: オンラインで、ローカルのフォルダF（名前「A」）を名前「B」に編集した場合、戻り値がRightで名前が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。その後のgetFoldersのFの名前が「B」。キューが1件増える [FLD-U01]
- **カテゴリ**: 正常系
- **対象メソッド**: updateFolder()
- **事前条件**: 接続状態がオンライン。フォルダF（名前「A」）がローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'F', name: 'B')` を呼び、その後 `getFolders` とキューの件数を確認する
- **期待結果**: 戻り値がRightで、名前が「B」、createdAtが編集前と等しく、updatedAtが編集前のupdatedAtより後。その後のgetFoldersのFの名前が「B」。キューが1件増える

### テストケース13: オフラインで、ローカルのフォルダF（名前「A」）を名前「B」に編集した場合、戻り値がRightで名前が「B」。その後のgetFoldersのFの名前が「B」。キューが1件増える [FLD-U02]
- **カテゴリ**: 正常系
- **対象メソッド**: updateFolder()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はFLD-U01と同じになることを確かめる）。フォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'F', name: 'B')` を呼ぶ
- **期待結果**: 戻り値がRightで、名前が「B」。キューが1件増える

### テストケース14: ローカルに存在しないidを指定して編集した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-U03]
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **事前条件**: なし
- **入力値・テスト条件**: userId=U, folderId='not-exist', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'not-exist', name: 'B')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース15: 削除済みのフォルダFを指定して編集した場合、戻り値がLeft(NotFoundFailure)。その後のgetFoldersにFが含まれない。キューの件数が変わらない [FLD-U04]
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **事前条件**: フォルダFが論理削除済み
- **入力値・テスト条件**: userId=U, folderId='F', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'F', name: 'B')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。その後のgetFoldersにFが含まれない。キューの件数が変わらない

### テストケース16: ローカルのフォルダF（名前「A」）の編集で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersのFの名前が「A」のまま。キューの件数が変わらない [FLD-U05]
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **事前条件**: フォルダF（名前「A」）がローカルにある。`FolderLocalDataSource.save` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'F', name: 'B')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後のFの名前が「A」のまま。キューの件数が変わらない

### テストケース17: ローカルのフォルダF（名前「A」）を、同じ名前「A」で編集した場合、戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える [FLD-U06]
- **カテゴリ**: 境界値
- **対象メソッド**: updateFolder()
- **事前条件**: フォルダF（名前「A」）がローカルにある
- **入力値・テスト条件**: userId=U, folderId='F', name='A'（編集前と同じ値）
- **操作手順**: `updateFolder(userId: U, folderId: 'F', name: 'A')` を呼ぶ
- **期待結果**: 戻り値がRightで、updatedAtが編集前のupdatedAtより後。キューが1件増える

### テストケース18: ユーザーVのフォルダGのidを指定して、Uとして編集した場合、戻り値がLeft(NotFoundFailure)。Gの名前は変わらない [FLD-U07]
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **事前条件**: フォルダGがユーザーVのものとしてローカルにある
- **入力値・テスト条件**: userId=U, folderId='G', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'G', name: 'B')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。Gの名前は変わらない

### テストケース19: ローカルのフォルダFの編集で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetFoldersのFの名前が編集前のまま [FLD-U08]
- **カテゴリ**: 異常系
- **対象メソッド**: updateFolder()
- **事前条件**: フォルダFがローカルにある。`SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F', name='B'
- **操作手順**: `updateFolder(userId: U, folderId: 'F', name: 'B')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、その後のgetFoldersのFの名前が編集前のまま

### テストケース20: オンラインで、ローカルのフォルダF（配下なし）を削除した場合、戻り値がRight(unit)。その後のgetFoldersにFが含まれない。ローカルのFのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える [FLD-X01]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **事前条件**: 接続状態がオンライン。配下を持たないフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼び、その後 `getFolders` とローカルの行、キューの件数を確認する
- **期待結果**: 戻り値がRight(unit)。その後のgetFoldersにFが含まれない。ローカルのFのdeletedAtが入り、updatedAtが削除前のupdatedAtより後。キューが1件増える

### テストケース21: オフラインで、ローカルのフォルダF（配下なし）を削除した場合、戻り値がRight(unit)。その後のgetFoldersにFが含まれない。キューが1件増える [FLD-X02]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はFLD-X01と同じになることを確かめる）。配下を持たないフォルダFがローカルにある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。その後のgetFoldersにFが含まれない。キューが1件増える

### テストケース22: フォルダFに子フォルダG、Gに単語W、Fに成績Rがある状態でFを削除した場合、戻り値がRight(unit)。ローカルのF・G・W・Rのdeletedatがすべて入る。getWords（G）にWが含まれない。getFlashcardResultsにRが含まれない。キューが4件（F・G・W・R）増える [FLD-X03]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **事前条件**: フォルダF、子フォルダG（親がF）、単語W（フォルダG）、成績R（フォルダF）がローカルにある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。ローカルのF・G・W・RのdeletedAtがすべて入る。Gの単語一覧にWが含まれない。成績一覧にRが含まれない。ユーザーUのキューが4件増える

### テストケース23: FLD-X03と同じ配下がある状態でFを削除した場合、ローカルのG・W・RのdeletedAtがFのdeletedAtと等しい [FLD-X04]
- **カテゴリ**: 正常系
- **対象メソッド**: deleteFolder()
- **事前条件**: FLD-X03と同じ配下（F・G・W・R）がローカルにある
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼び、各行のdeletedAtを比較する
- **期待結果**: G・W・RのdeletedAtがFのdeletedAtと等しい

### テストケース24: ローカルに存在しないidを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-X05]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteFolder()
- **事前条件**: なし
- **入力値・テスト条件**: userId=U, folderId='not-exist'
- **操作手順**: `deleteFolder(userId: U, folderId: 'not-exist')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース25: 削除済みのフォルダFを指定して削除した場合、戻り値がLeft(NotFoundFailure)。キューの件数が変わらない [FLD-X06]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteFolder()
- **事前条件**: フォルダFが論理削除済み
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。ユーザーUのキューの件数が変わらない

### テストケース26: FLD-X03と同じ配下がある状態でFを削除し、配下の単語Wの保存が失敗した場合、戻り値がLeft(UnknownFailure)。ローカルのF・G・W・RのdeletedAtがすべてnullのまま。キューの件数が変わらない [FLD-X07]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteFolder()
- **事前条件**: FLD-X03と同じ配下（F・G・W・R）がローカルにある。`WordLocalDataSource.markDeleted` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、F・G・W・RのdeletedAtがすべてnullのまま。ユーザーUのキューの件数が変わらない

### テストケース27: ユーザーVのフォルダGのidを指定して、Uとして削除した場合、戻り値がLeft(NotFoundFailure)。GのdeletedAtはnullのまま [FLD-X08]
- **カテゴリ**: 異常系
- **対象メソッド**: deleteFolder()
- **事前条件**: フォルダGがユーザーVのものとしてローカルにある
- **入力値・テスト条件**: userId=U, folderId='G'
- **操作手順**: `deleteFolder(userId: U, folderId: 'G')` を呼ぶ
- **期待結果**: 戻り値がLeft(NotFoundFailure)。GのdeletedAtはnullのまま

### テストケース28: 削除済みの子フォルダG（deletedAtがFの削除より前）を持つフォルダFを削除した場合、ローカルのGのdeletedAtが変わらない。キューが1件（F）増える [FLD-X09]
- **カテゴリ**: 境界値
- **対象メソッド**: deleteFolder()
- **事前条件**: フォルダF、子フォルダG（親がF）がローカルにある。Gは、Fの削除より前の時刻ですでに論理削除済み
- **入力値・テスト条件**: userId=U, folderId='F'
- **操作手順**: `deleteFolder(userId: U, folderId: 'F')` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。Gの再帰的走査は未削除の子だけを対象にするため、GのdeletedAtは変わらず、ユーザーUのキューはF分の1件だけ増える
