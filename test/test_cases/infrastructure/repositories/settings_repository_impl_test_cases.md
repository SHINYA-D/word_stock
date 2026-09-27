## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/repositories/settings_repository_impl.dart |
| クラス名 | SettingsRepositoryImpl |
| テスト対象メソッド | getSettings() / updateSettings() |
| 仕様書 | docs/detailed_design/online_offline/settings_repository.md |

## テストケース一覧

| # | テスト名 | 仕様ID | カテゴリ | 対象メソッド | 状態 |
|---|---------|--------|---------|-----------|------|
| 1 | ローカルにUの設定がない場合、戻り値がRightでカラーテーマ「indigo」・ダークモードfalse [STG-R01] | STG-R01 #11597a | 正常系 | getSettings() | ✅ |
| 2 | ローカルにUの設定（カラーテーマ「teal」・ダークモードtrue）がある場合、戻り値がRightでカラーテーマ「teal」・ダークモードtrue [STG-R02] | STG-R02 #30d9e9 | 正常系 | getSettings() | ✅ |
| 3 | ローカルにUの設定がなく、ユーザーVの設定（カラーテーマ「pink」）がある場合、戻り値がRightでカラーテーマ「indigo」 [STG-R03] | STG-R03 #9d4fe3 | 正常系 | getSettings() | ✅ |
| 4 | オフラインで、ローカルにUの設定（カラーテーマ「teal」）がある場合、戻り値がRightでカラーテーマ「teal」 [STG-R04] | STG-R04 #f1579b | 正常系 | getSettings() | ✅ |
| 5 | ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [STG-R05] | STG-R05 #8e198e | 異常系 | getSettings() | ✅ |
| 6 | オンラインで、Uの設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」・ダークモードtrueに変更した場合、戻り値がRight(unit)。その後のgetSettingsがカラーテーマ「teal」・ダークモードtrueで、updatedAtが変更前のupdatedAtより後。キューが1件増える [STG-U01] | STG-U01 #9920ef | 正常系 | updateSettings() | ✅ |
| 7 | オフラインで、Uの設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」に変更した場合、戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」。キューが1件増える [STG-U02] | STG-U02 #fbac31 | 正常系 | updateSettings() | ✅ |
| 8 | ローカルにUの設定がない状態で、カラーテーマ「teal」に変更した場合、戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」で、updatedAtがnullでない。キューが1件増える [STG-U03] | STG-U03 #500cd1 | 境界値 | updateSettings() | ✅ |
| 9 | Uの設定（カラーテーマ「indigo」）の変更で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetSettingsのカラーテーマが「indigo」のまま。キューの件数が変わらない [STG-U04] | STG-U04 #f58ca1 | 異常系 | updateSettings() | ✅ |
| 10 | Uの設定（カラーテーマ「indigo」）の変更で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetSettingsのカラーテーマが「indigo」のまま [STG-U05] | STG-U05 #b02245 | 異常系 | updateSettings() | ✅ |
| 11 | Uの設定（カラーテーマ「indigo」・ダークモードfalse）がある状態で、同じ値で変更した場合、戻り値がRight(unit)。updatedAtが変更前のupdatedAtより後。キューが1件増える [STG-U06] | STG-U06 #25ce78 | 境界値 | updateSettings() | ✅ |
| 12 | 変更した直後（送信前）は、ローカルのUの設定のsyncStatusがpending [STG-U07] | STG-U07 #16ddf9 | 正常系 | updateSettings() | ✅ |
| 13 | Uの設定とユーザーVの設定（カラーテーマ「pink」）がある状態で、Uの設定をカラーテーマ「teal」に変更した場合、Vの設定のカラーテーマが「pink」のまま [STG-U08] | STG-U08 #07adcc | 境界値 | updateSettings() | ✅ |

## テストケース詳細

### テストケース1: ローカルにUの設定がない場合、戻り値がRightでカラーテーマ「indigo」・ダークモードfalse [STG-R01]
- **カテゴリ**: 正常系
- **対象メソッド**: getSettings()
- **事前条件**: ローカルにユーザーUの設定行がない
- **入力値・テスト条件**: userId=U
- **操作手順**: `getSettings(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、カラーテーマ「indigo」・ダークモードfalse（既定値）

### テストケース2: ローカルにUの設定（カラーテーマ「teal」・ダークモードtrue）がある場合、戻り値がRightでカラーテーマ「teal」・ダークモードtrue [STG-R02]
- **カテゴリ**: 正常系
- **対象メソッド**: getSettings()
- **事前条件**: ローカルにユーザーUの設定（カラーテーマ「teal」・ダークモードtrue）がある
- **入力値・テスト条件**: userId=U
- **操作手順**: `getSettings(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、カラーテーマ「teal」・ダークモードtrue

### テストケース3: ローカルにUの設定がなく、ユーザーVの設定（カラーテーマ「pink」）がある場合、戻り値がRightでカラーテーマ「indigo」 [STG-R03]
- **カテゴリ**: 正常系
- **対象メソッド**: getSettings()
- **事前条件**: ローカルにユーザーUの設定行はなく、ユーザーVの設定（カラーテーマ「pink」）だけがある
- **入力値・テスト条件**: userId=U
- **操作手順**: `getSettings(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、カラーテーマ「indigo」（Vの設定は返らない）

### テストケース4: オフラインで、ローカルにUの設定（カラーテーマ「teal」）がある場合、戻り値がRightでカラーテーマ「teal」 [STG-R04]
- **カテゴリ**: 正常系
- **対象メソッド**: getSettings()
- **事前条件**: 接続状態がオフライン。ローカルにユーザーUの設定（カラーテーマ「teal」）がある（本Repositoryは接続状態に依存しない設計のため、結果はSTG-R02と同じになることを確かめる）
- **入力値・テスト条件**: userId=U
- **操作手順**: `getSettings(userId: U)` を呼ぶ
- **期待結果**: 戻り値がRightで、カラーテーマ「teal」

### テストケース5: ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [STG-R05]
- **カテゴリ**: 異常系
- **対象メソッド**: getSettings()
- **事前条件**: `SettingsLocalDataSource.findByUserId` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U
- **操作手順**: `getSettings(userId: U)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)

### テストケース6: オンラインで、Uの設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」・ダークモードtrueに変更した場合、戻り値がRight(unit)。その後のgetSettingsがカラーテーマ「teal」・ダークモードtrueで、updatedAtが変更前のupdatedAtより後。キューが1件増える [STG-U01]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSettings()
- **事前条件**: 接続状態がオンライン。ローカルにユーザーUの設定（カラーテーマ「indigo」、updatedAt=2023-01-01）がある
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal', darkMode: true)
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼び、その後 `getSettings` とキューの件数を確認する
- **期待結果**: 戻り値がRight(unit)。その後のgetSettingsがカラーテーマ「teal」・ダークモードtrueで、updatedAtが変更前のupdatedAtより後。ユーザーUのキューが1件増える

### テストケース7: オフラインで、Uの設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」に変更した場合、戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」。キューが1件増える [STG-U02]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSettings()
- **事前条件**: 接続状態がオフライン（本Repositoryは接続状態に依存しない設計のため、結果はSTG-U01と同じになることを確かめる）。ローカルにユーザーUの設定（カラーテーマ「indigo」）がある
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal')
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」。キューが1件増える

### テストケース8: ローカルにUの設定がない状態で、カラーテーマ「teal」に変更した場合、戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」で、updatedAtがnullでない。キューが1件増える [STG-U03]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSettings()
- **事前条件**: ローカルにユーザーUの設定行がない
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal')
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」で、updatedAtがnullでない。キューが1件増える

### テストケース9: Uの設定（カラーテーマ「indigo」）の変更で、ローカルへの保存が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetSettingsのカラーテーマが「indigo」のまま。キューの件数が変わらない [STG-U04]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings()
- **事前条件**: ローカルにユーザーUの設定（カラーテーマ「indigo」）がある。`SettingsLocalDataSource.save` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal')
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。その後のカラーテーマが「indigo」のまま。ユーザーUのキューの件数が変わらない

### テストケース10: Uの設定（カラーテーマ「indigo」）の変更で、保存は成功しキューへの登録が失敗した場合、戻り値がLeft(UnknownFailure)。その後のgetSettingsのカラーテーマが「indigo」のまま [STG-U05]
- **カテゴリ**: 異常系
- **対象メソッド**: updateSettings()
- **事前条件**: ローカルにユーザーUの設定（カラーテーマ「indigo」）がある。`SyncQueueDataSource.enqueueInTransaction` が例外を投げるように差し替えている
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal')
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼ぶ
- **期待結果**: 戻り値がLeft(UnknownFailure)。トランザクションがロールバックされ、その後のカラーテーマが「indigo」のまま

### テストケース11: Uの設定（カラーテーマ「indigo」・ダークモードfalse）がある状態で、同じ値で変更した場合、戻り値がRight(unit)。updatedAtが変更前のupdatedAtより後。キューが1件増える [STG-U06]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSettings()
- **事前条件**: ローカルにユーザーUの設定（カラーテーマ「indigo」・ダークモードfalse、updatedAt=2023-01-01）がある
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'indigo', darkMode: false)（変更前と同じ値）
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼ぶ
- **期待結果**: 戻り値がRight(unit)。updatedAtが変更前のupdatedAtより後。キューが1件増える

### テストケース12: 変更した直後（送信前）は、ローカルのUの設定のsyncStatusがpending [STG-U07]
- **カテゴリ**: 正常系
- **対象メソッド**: updateSettings()
- **事前条件**: ローカルにユーザーUの設定がある
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal')
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼び、直後にローカルの行を直接参照する
- **期待結果**: ローカルの行のsyncStatusが`pending`

### テストケース13: Uの設定とユーザーVの設定（カラーテーマ「pink」）がある状態で、Uの設定をカラーテーマ「teal」に変更した場合、Vの設定のカラーテーマが「pink」のまま [STG-U08]
- **カテゴリ**: 境界値
- **対象メソッド**: updateSettings()
- **事前条件**: ローカルにユーザーUの設定と、ユーザーVの設定（カラーテーマ「pink」）がある
- **入力値・テスト条件**: userId=U, settings=UserSettings(colorTheme: 'teal')
- **操作手順**: `updateSettings(userId: U, settings: ...)` を呼ぶ
- **期待結果**: Vの設定のカラーテーマが「pink」のまま（Uの変更に巻き込まれない）
