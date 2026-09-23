# word_edit_page_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/word/word_edit_page.dart |
| クラス名 | WordEditPage |
| テスト対象メソッド | _expand() / _collapse() / _save() / _dismissValidationError() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 初期表示で表・裏カードに既存の値が表示される | 正常系 | build() | ✅ |
| 2 | 表カードをタップすると展開しTextFieldに既存の値が入っている | 正常系 | _expand() | ✅ |
| 3 | 未変更のまま展開した場合、保存ボタンが無効な状態になる | 境界値 | _isDirty | ✅ |
| 4 | 表カードの文字を変更すると保存ボタンが有効になる | 境界値 | _isDirty | ✅ |
| 5 | 表カードを変更して保存すると更新され折りたたまれた状態で新しい値が表示される | 正常系 | _save() | ✅ |
| 6 | 展開中に閉じるアイコンをタップすると変更が破棄され元の値に戻る | 正常系 | _collapse() | ✅ |
| 7 | テキストを空にして保存するとバリデーションエラーメッセージが表示される | 異常系 | _save() | ✅ |
| 8 | バリデーションエラー表示中にカードをタップするとエラーが消える | 正常系 | _dismissValidationError() | ✅ |
| 9 | 更新に失敗した場合、エラーのスナックバーが表示される | 異常系 | _save() | ✅ |
| 10 | 展開中に戻る操作をすると変更を破棄して画面は閉じない | 異常系 | _collapse() (PopScope) | ✅ |

## テストケース詳細

### テストケース1: 初期表示で表・裏カードに既存の値が表示される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `WordListViewModel` はサブクラス override せず本物の実装（`buildWithMockRepositories()` の `MockWordRepository`、folder-1/word-1 = front='apple', back='りんご'）をそのまま使う
- **入力値・テスト条件**: `WordEditPage(folderId: 'folder-1', word: 対象Word)`（`_testWord` は Mock 側の word-1 と front/back を一致させてある）
- **操作手順**: `WordEditPage` を pump → `pump(250ms)`（`MockWordRepository.getWords()` の `Future.delayed(200ms)` を明示的に進める）→ `pumpAndSettle()`
- **期待結果**: 「表」「裏」ラベル、'apple'、'りんご'、AppBar タイトル「単語を編集」が表示される

### テストケース2: 表カードをタップすると展開しTextFieldに既存の値が入っている
- **カテゴリ**: 正常系
- **対象メソッド**: _expand()
- **事前条件**: 折りたたみ状態（`_expandedSide == null`）で表示済み
- **入力値・テスト条件**: なし
- **操作手順**: `find.text('表')` をタップ → `pumpAndSettle()`
- **期待結果**: `TextField` が1つ表示され、その `controller.text` が既存値 'apple' になっている

### テストケース3: 未変更のまま展開した場合、保存ボタンが無効な状態になる
- **カテゴリ**: 境界値
- **対象メソッド**: _isDirty（変更有無の境界）
- **事前条件**: 表カードを展開済み。テキストは未変更（既存値のまま）
- **入力値・テスト条件**: なし
- **操作手順**: 保存ボタンの `IgnorePointer.ignoring` を確認
- **期待結果**: `ignoring == true`（保存ボタンが無効。`_isDirty == false` のため）

### テストケース4: 表カードの文字を変更すると保存ボタンが有効になる
- **カテゴリ**: 境界値
- **対象メソッド**: _isDirty（変更有無の境界）
- **事前条件**: 表カードを展開済み
- **入力値・テスト条件**: 'apple' → 'apricot' に変更
- **操作手順**: `enterText(TextField, 'apricot')` → `pumpAndSettle()` → `IgnorePointer.ignoring` を確認
- **期待結果**: `ignoring == false`（保存ボタンが有効になる）

### テストケース5: 表カードを変更して保存すると更新され折りたたまれた状態で新しい値が表示される
- **カテゴリ**: 正常系
- **対象メソッド**: _save()
- **事前条件**: `WordListViewModel.updateWord()` はoverrideせず、実際の `UpdateWordUseCase`（Mock `WordRepository`）をそのまま呼び出す。表カードを展開しテキストを変更済み
- **入力値・テスト条件**: front = 'apricot'
- **操作手順**: 表カードの「保存」ボタンをタップ → `pumpAndSettle()`
- **期待結果**: 展開時のみ表示される閉じるアイコンが消え（折りたたみ状態）、更新後の 'apricot' が表示される

### テストケース6: 展開中に閉じるアイコンをタップすると変更が破棄され元の値に戻る
- **カテゴリ**: 正常系
- **対象メソッド**: _collapse()
- **事前条件**: 表カードを展開しテキストを 'temp' に変更済み（未保存）
- **入力値・テスト条件**: なし
- **操作手順**: 展開時に表示される閉じるアイコン（`Icons.close`）をタップ → `pumpAndSettle()`
- **期待結果**: 元の値 'apple' が表示され、未保存の 'temp' は表示されない（`discard: true` で破棄される）

### テストケース7: テキストを空にして保存するとバリデーションエラーメッセージが表示される
- **カテゴリ**: 異常系
- **対象メソッド**: _save()
- **事前条件**: 表カードを展開しテキストを空文字に変更済み
- **入力値・テスト条件**: front = ''
- **操作手順**: テキストを空にする → 表カードの「保存」ボタンをタップ → `pumpAndSettle()`
- **期待結果**: `AnimatedWordCard.validationMessage`（「1文字以上入力してください！」）が表示される

### テストケース8: バリデーションエラー表示中にカードをタップするとエラーが消える
- **カテゴリ**: 正常系
- **対象メソッド**: _dismissValidationError()
- **事前条件**: テストケース7の手順でバリデーションエラーを表示させた状態
- **入力値・テスト条件**: なし
- **操作手順**: `TextField` をタップ → `pumpAndSettle()`
- **期待結果**: バリデーションエラーメッセージが非表示になる

### テストケース9: 更新に失敗した場合、エラーのスナックバーが表示される
- **カテゴリ**: 異常系
- **対象メソッド**: _save()
- **事前条件**: ViewModel はoverrideしない。`WordEditPage` に渡す `word.id`（`_missingWord.id`）を `MockWordRepository` の folder-1 ストアに存在しないIDにしておき、本物の `UpdateWordUseCase` / `MockWordRepository.updateWord()` から `Failure.notFound()`（Left）を返させる
- **入力値・テスト条件**: word = `_missingWord`（id: 'word-does-not-exist'）, front = 'apricot'
- **操作手順**: 表カードに変更を入力し保存ボタンをタップ → `pumpAndSettle()`
- **期待結果**: `ref.listen` 経由で「更新に失敗しました」の `SnackBar` が表示される（`WordEditPage` は Failure の種類によらず固定文言を表示するため、`Failure.notFound()` でも同文言になる）

### テストケース10: 展開中に戻る操作をすると変更を破棄して画面は閉じない
- **カテゴリ**: 異常系
- **対象メソッド**: _collapse()（PopScope 経由）
- **事前条件**: `WordEditPage` を1つ前の画面から `Navigator.push` した状態。表カードを展開しテキストを 'temp' に変更済み（未保存）
- **入力値・テスト条件**: なし
- **操作手順**: AppBar の戻るボタン（`Back` tooltip）をタップ → `pumpAndSettle()`
- **期待結果**: `PopScope.canPop == false` のため画面は閉じられず `WordEditPage` が表示されたまま。変更は破棄され元の値 'apple' が表示される（'temp' は表示されない）

## 対象外

- WordEditPage は `AnimatedWordCard` のアニメーション表現（`AnimatedContainer` の高さ遷移等）そのものはロジックを持たない純粋UIのため対象外（L119-176 のレイアウト計算・アニメーション用の高さ分岐）。

## 備考

- `WordListViewModel` はサブクラス override を行わず、`buildWithMockRepositories()` が注入する本物の `WordListViewModel` + `MockWordRepository` をそのまま使う（ロジックの二重テストを避けるため。ロジック網羅自体は `test/presentation/word/word_list_view_model_test.dart` が担当）。
- `MockWordRepository.getWords()` / `updateWord()` は `Future.delayed(200ms)` を挟むが、`WordEditPage` は `wordListViewModelProvider` を `ref.listen` のみで監視し `ref.watch` しないため、build() 完了時に新しいフレームが自動スケジュールされない。そのため初期表示だけを検証するテストケース1では `pumpAndSettle()` の前に明示的に `pump(const Duration(milliseconds: 250))` を挟み、残留タイマーによる `A Timer is still pending even after the widget tree was disposed.` を回避している（他のケースはタップ操作が複数回挟まるため副次的に解消される）。
