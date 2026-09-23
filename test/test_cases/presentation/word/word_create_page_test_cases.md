# word_create_page_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/word/word_create_page.dart |
| クラス名 | WordCreatePage |
| テスト対象メソッド | _expandFront() / _expandBack() / _confirmFront() / _saveBack() / _collapse() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 初期表示で表・裏カードのラベルが表示される | 正常系 | build() | ✅ |
| 2 | 表カードをタップすると展開しTextFieldが表示される | 正常系 | _expandFront() | ✅ |
| 3 | 表カードに文字を入力すると保存ボタンが有効になる | 境界値 | _canConfirmFront | ✅ |
| 4 | 表が未確定のまま裏カードをタップすると確認ダイアログが表示される | 異常系 | _expandBack() | ✅ |
| 5 | 確認ダイアログのOKをタップするとダイアログが閉じる | 正常系 | _expandBack() | ✅ |
| 6 | 表カードに入力して保存すると表カードが折りたたまれる | 正常系 | _confirmFront() | ✅ |
| 7 | 表を確定後に裏カードをタップするとダイアログを出さずに展開できる | 正常系 | _expandBack() | ✅ |
| 8 | 展開中に閉じるアイコンをタップすると折りたたまれる | 正常系 | _collapse() | ✅ |
| 9 | 表裏に入力して裏カードを保存すると単語が保存され画面が閉じる | 正常系 | _saveBack() | ✅ |
| 10 | 保存に失敗した場合、エラーのスナックバーが表示される | 異常系 | _saveBack() | ✅ |

## 実行環境について

ケース1〜9は `WordListViewModel` を override せず、`buildWithMockRepositories()` が注入する
`MockWordRepository`（`lib/infrastructure/repositories/mock/mock_word_repository.dart`）経由の
**本物の `build()` / `createWord()`** をそのまま動かして検証する。
`MockWordRepository` の各メソッドは `Future.delayed(Duration(milliseconds: 200))` で応答するため、
`pumpWidget` 直後・`WordCreatePage` が新たにマウントされた直後には
`await tester.pump(const Duration(milliseconds: 250)); await tester.pumpAndSettle();`
（テストファイル内の `_pumpAndSettleWordCreatePage` ヘルパー）で実時間を進め、初期フェッチの
Future を確実に解決させてから操作する。これを怠ると、テスト終了時に該当 Future の
`Timer` が未解決のまま残り「A Timer is still pending even after the widget tree was disposed」で
失敗する。

ケース10（保存失敗）のみ `_FailingCreateWordListViewModel` で `WordListViewModel` を override する。
`MockWordRepository.createWord()` は常に成功（`Right`）を返す実装であり、失敗（`Left`）を
意図的に返させる手段を持たないため、失敗系の描画確認（スナックバー表示）をWidgetテストの範囲で
検証するには override が唯一の方法。ただし `result.fold(...)` のようなロジックの再実装はせず、
`state = AsyncValue.error(...)` を直接セットするだけの最小限の override に留めている
（`WordListViewModel.createWord()` 本来のロジックのテストは
`test/presentation/word/word_list_view_model_test.dart` が担当し、二重化を避ける）。

## テストケース詳細

### テストケース1: 初期表示で表・裏カードのラベルが表示される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `WordListViewModel` は override せず、`MockWordRepository` 経由の本物の `build()` をそのまま使用
- **入力値・テスト条件**: なし（初期表示のみ）
- **操作手順**: `WordCreatePage(folderId: 'folder-1')` を pump し `_pumpAndSettleWordCreatePage()` で初期フェッチを解決させる
- **期待結果**: 「表」「裏」ラベルと AppBar タイトル「単語を追加」が表示される

### テストケース2: 表カードをタップすると展開しTextFieldが表示される
- **カテゴリ**: 正常系
- **対象メソッド**: _expandFront()
- **事前条件**: 折りたたみ状態（`_expandedSide == null`）で表示済み
- **入力値・テスト条件**: なし
- **操作手順**: `find.text('表')` をタップ → `pumpAndSettle()`
- **期待結果**: `TextField` が1つ表示される（表カードが展開状態になる）

### テストケース3: 表カードに文字を入力すると保存ボタンが有効になる
- **カテゴリ**: 境界値
- **対象メソッド**: _canConfirmFront（入力有無の境界）
- **事前条件**: 表カードを展開済み
- **入力値・テスト条件**: 入力前は空文字、入力後は 'apple'
- **操作手順**: 保存ボタンの `IgnorePointer.ignoring` を確認 → `enterText(TextField, 'apple')` → 再度確認
- **期待結果**: 入力前は `ignoring == true`（保存ボタンが無効）、入力後は `ignoring == false`（保存ボタンが有効）

### テストケース4: 表が未確定のまま裏カードをタップすると確認ダイアログが表示される
- **カテゴリ**: 異常系
- **対象メソッド**: _expandBack()
- **事前条件**: 表カードが未確定（`_confirmedFrontText == null`）
- **入力値・テスト条件**: なし
- **操作手順**: `find.text('裏')` をタップ → `pumpAndSettle()`
- **期待結果**: 「入力が未完了です」「表カードの入力を完了させてください」ダイアログが表示される

### テストケース5: 確認ダイアログのOKをタップするとダイアログが閉じる
- **カテゴリ**: 正常系
- **対象メソッド**: _expandBack()
- **事前条件**: テストケース4と同様にダイアログを表示させた状態
- **入力値・テスト条件**: なし
- **操作手順**: ダイアログの「OK」をタップ → `pumpAndSettle()`
- **期待結果**: 「入力が未完了です」の文言が非表示になる（ダイアログが閉じる）

### テストケース6: 表カードに入力して保存すると表カードが折りたたまれる
- **カテゴリ**: 正常系
- **対象メソッド**: _confirmFront()
- **事前条件**: 表カードを展開しテキストを入力済み
- **入力値・テスト条件**: front = 'apple'
- **操作手順**: 表カードの「保存」ボタンをタップ → `pumpAndSettle()`
- **期待結果**: 展開時のみ表示される閉じるアイコンが消え、確定した 'apple' の文字列が表示される（DBへは反映されず値のみ確定）

### テストケース7: 表を確定後に裏カードをタップするとダイアログを出さずに展開できる
- **カテゴリ**: 正常系
- **対象メソッド**: _expandBack()
- **事前条件**: テストケース6の手順で表カードを確定済み
- **入力値・テスト条件**: なし
- **操作手順**: `find.text('裏')` をタップ → `pumpAndSettle()`
- **期待結果**: 確認ダイアログは表示されず、裏カードが展開され `TextField` が表示される

### テストケース8: 展開中に閉じるアイコンをタップすると折りたたまれる
- **カテゴリ**: 正常系
- **対象メソッド**: _collapse()
- **事前条件**: 表カードを展開済み
- **入力値・テスト条件**: なし
- **操作手順**: 展開時に表示される閉じるアイコン（`Icons.close`）をタップ → `pumpAndSettle()`
- **期待結果**: 閉じるアイコンが非表示になる（折りたたみ状態に戻る）

### テストケース9: 表裏に入力して裏カードを保存すると単語が保存され画面が閉じる
- **カテゴリ**: 正常系
- **対象メソッド**: _saveBack()
- **事前条件**: `WordCreatePage` を1つ前の画面から `Navigator.push` した状態。`WordListViewModel` は override せず、`createWord()` は実際の `CreateWordUseCase`（Mock `WordRepository`）をそのまま呼び出す
- **入力値・テスト条件**: front = 'apple', back = 'りんご'
- **操作手順**: 表カードに入力し保存 → 裏カードに入力し保存 → `pumpAndSettle()`
- **期待結果**: `WordCreatePage` が画面から消え（`Navigator.pop()`）、元の画面（'open' ボタンのある画面）が表示される

### テストケース10: 保存に失敗した場合、エラーのスナックバーが表示される
- **カテゴリ**: 異常系
- **対象メソッド**: _saveBack()
- **事前条件**: `WordListViewModel.createWord()` が常に `AsyncValue.error(Failure.unknown('追加に失敗しました'))` を返すサブクラスにoverride。`WordCreatePage` は1つ前の画面から `Navigator.push` した状態
- **入力値・テスト条件**: front = 'apple', back = 'りんご'（保存自体はViewModel側で失敗させる）
- **操作手順**: 表カードに入力し保存 → 裏カードに入力し保存 → `pumpAndSettle()`
- **期待結果**: `ref.listen` 経由で「追加に失敗しました」の `SnackBar` が表示される

## 対象外

- WordCreatePage は `mixed with AnimatedWordCard` のアニメーション表現（`AnimatedContainer` の高さ遷移等）そのものはロジックを持たない純粋UIのため対象外。`showValidationError` のバリデーションメッセージ表示分岐は保存ボタンが `IgnorePointer` で無効化されておりUI操作からは到達できないため対象外（`_confirmFront()` / `_saveBack()` 内の `_showValidationError = true` 分岐、L88, L101）。
