# flashcard_mode_view_model_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/flashcard_mode/flashcard_mode_view_model.dart |
| クラス名 | FlashcardModeViewModel |
| テスト対象メソッド | build() / start() / flip() / answer() |

## 実行環境について

`FlashcardModeViewModel` は `SaveFlashcardResultUseCase` にのみ依存するため、
`ProviderContainer(overrides: [...])` と手書き Fake（`FakeSaveFlashcardResultUseCase`）で
Widget を pump せずに `test()` で検証する。Widget 経由の描画・操作は
`test/presentation/flashcard_mode/*_page_test.dart`（Widgetテスト）の担当であり、本ファイルでは
ロジック（出題順・めくり状態・正誤判定・次カード遷移・終了判定・保存結果の `fold` 分岐・ガード条件）
のみを対象とする。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 初期状態では未開始・未終了・0件の state になる | 正常系 | build() | ✅ |
| 2 | 単語が1件以上ある場合、先頭の単語で開始状態になる | 正常系 | start() | ✅ |
| 3 | 単語が0件の場合、開始と同時に終了状態になる | 境界値 | start() | ✅ |
| 4 | shuffle: true の場合、全単語が含まれたまま出題順が構成される | 正常系 | start() | ✅ |
| 5 | 開始済みかつ未終了の場合、isFlipped が反転する | 正常系 | flip() | ✅ |
| 6 | 開始前に呼び出した場合、state は変化しない | 異常系 | flip() | ✅ |
| 7 | 終了済みの場合、isFlipped は変化しない | 異常系 | flip() | ✅ |
| 8 | 最終カードでない場合、正誤カウントが加算され次の単語へ進みめくり状態がリセットされる | 正常系 | answer() | ✅ |
| 9 | 不正解の場合、correctCount は加算されず次の単語へ進む | 正常系 | answer() | ✅ |
| 10 | 最終カードで保存に成功した場合、終了状態になり合計正解数が反映される | 正常系 | answer() | ✅ |
| 11 | 保存の完了を待つ間、isSubmitting が true になる | 正常系 | answer() | ✅ |
| 12 | 保存が isSubmitting 中にもう一度呼ばれた場合、二重送信されない | 異常系 | answer() | ✅ |
| 13 | 保存に失敗した場合（ネットワーク）、errorMessage が設定され終了状態にならない | 異常系 | answer() | ✅ |
| 14 | 保存に失敗した場合（認証）、認証エラーメッセージが設定される | 異常系 | answer() | ✅ |
| 15 | 保存に失敗した場合（データ未検出）、未検出エラーメッセージが設定される | 異常系 | answer() | ✅ |
| 16 | 保存に失敗した場合（不明なエラー）、詳細メッセージ付きのエラーが設定される | 異常系 | answer() | ✅ |
| 17 | 開始前に呼び出した場合、UseCase は呼ばれず state は変化しない | 異常系 | answer() | ✅ |
| 18 | 終了済みの場合、UseCase は呼ばれず state は変化しない | 異常系 | answer() | ✅ |

## テストケース詳細

### テストケース1: 初期状態では未開始・未終了・0件の state になる
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: `ProviderContainer` を生成しただけで `start()` は未呼び出し。
- **入力値・テスト条件**: なし。
- **操作手順**: `container.read(flashcardModeViewModelProvider)` を読む。
- **期待結果**: `isStarted=false`, `isFinished=false`, `currentWord=null`, `currentIndex=0`, `total=0`, `isFlipped=false`, `correctCount=0`。

### テストケース2: 単語が1件以上ある場合、先頭の単語で開始状態になる
- **カテゴリ**: 正常系
- **対象メソッド**: start()
- **事前条件**: `testWords`（3件）を用意。
- **入力値・テスト条件**: `words: testWords, shuffle: false`。
- **操作手順**: `notifier.start(...)` を呼ぶ。
- **期待結果**: `isStarted=true`, `isFinished=false`, `currentWord=testWords[0]`, `currentIndex=0`, `total=3`, `isFlipped=false`, `correctCount=0`。

### テストケース3: 単語が0件の場合、開始と同時に終了状態になる
- **カテゴリ**: 境界値
- **対象メソッド**: start()
- **事前条件**: なし。
- **入力値・テスト条件**: `words: []`。
- **操作手順**: `notifier.start(...)` を呼ぶ。
- **期待結果**: `isStarted=true`, `isFinished=true`, `currentWord=null`, `currentIndex=0`, `total=0`, `correctCount=0`。

### テストケース4: shuffle: true の場合、全単語が含まれたまま出題順が構成される
- **カテゴリ**: 正常系
- **対象メソッド**: start()
- **事前条件**: `testWords`（3件）を用意。
- **入力値・テスト条件**: `words: testWords, shuffle: true`。
- **操作手順**: `notifier.start(...)` を呼ぶ。
- **期待結果**: `total=3` かつ `currentWord` が `testWords` のいずれかに含まれる（乱数依存のため順序自体は固定検証しない）。

### テストケース5: 開始済みかつ未終了の場合、isFlipped が反転する
- **カテゴリ**: 正常系
- **対象メソッド**: flip()
- **事前条件**: `start()` 済み。
- **入力値・テスト条件**: `flip()` を2回連続で呼ぶ。
- **操作手順**: 1回目 → `isFlipped=true` を確認、2回目 → `isFlipped=false` を確認。
- **期待結果**: 呼ぶたびに `isFlipped` が反転する。

### テストケース6: 開始前に呼び出した場合、state は変化しない
- **カテゴリ**: 異常系
- **対象メソッド**: flip()
- **事前条件**: `start()` 未呼び出し。
- **入力値・テスト条件**: `flip()` を呼ぶ。
- **操作手順**: 呼び出し前後の state を比較。
- **期待結果**: state は変化しない（ガード条件 `!state.isStarted` で早期return）。

### テストケース7: 終了済みの場合、isFlipped は変化しない
- **カテゴリ**: 異常系
- **対象メソッド**: flip()
- **事前条件**: 単語0件で `start()` し、`isFinished=true` の状態。
- **入力値・テスト条件**: `flip()` を呼ぶ。
- **操作手順**: 呼び出し後の `isFlipped` を確認。
- **期待結果**: `isFlipped=false` のまま変化しない。

### テストケース8: 最終カードでない場合、正誤カウントが加算され次の単語へ進みめくり状態がリセットされる
- **カテゴリ**: 正常系
- **対象メソッド**: answer()
- **事前条件**: `testWords`（3件）で `start()`、`flip()` で `isFlipped=true` にしておく。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: `await notifier.answer(isCorrect: true)`。
- **期待結果**: `currentWord=testWords[1]`, `currentIndex=1`, `correctCount=1`, `isFlipped=false`, `isFinished=false`。UseCase は呼ばれない。

### テストケース9: 不正解の場合、correctCount は加算されず次の単語へ進む
- **カテゴリ**: 正常系
- **対象メソッド**: answer()
- **事前条件**: `testWords`（3件）で `start()`。
- **入力値・テスト条件**: `answer(isCorrect: false)`。
- **操作手順**: `await notifier.answer(isCorrect: false)`。
- **期待結果**: `correctCount=0`, `currentIndex=1`。

### テストケース10: 最終カードで保存に成功した場合、終了状態になり合計正解数が反映される
- **カテゴリ**: 正常系
- **対象メソッド**: answer()
- **事前条件**: 単語1件で `start()`。`FakeSaveFlashcardResultUseCase` は `Right(FlashcardResult(...))` を返す。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: `await notifier.answer(isCorrect: true)`。
- **期待結果**: `isFinished=true`, `isSubmitting=false`, `correctCount=1`, `total=1`。UseCase が `userId`/`folderId`/`totalCount`/`correctCount` を正しい引数で1回だけ呼ばれる。

### テストケース11: 保存の完了を待つ間、isSubmitting が true になる
- **カテゴリ**: 正常系
- **対象メソッド**: answer()
- **事前条件**: 単語1件で `start()`。`FakeSaveFlashcardResultUseCase` に `Completer` を渡し、`call()` の完了を制御する。
- **入力値・テスト条件**: `answer(isCorrect: true)` を呼び出した直後（`Completer` 未完了）。
- **操作手順**: `notifier.answer(isCorrect: true)` を呼び出した**直後・同一同期区間で** `state.isSubmitting` を確認する
  （`answer()` は async 関数のため、`Completer` 待ちの `await` に到達するまでの `isSubmitting=true` への代入は
  呼び出しと同じ同期区間で完了する。ここに `Future.delayed` 等のマクロタスクを挟むと、リスナーを持たない
  `AutoDisposeNotifierProvider` が破棄・再生成され、初期状態＝`isSubmitting=false` に見えてしまうため挟まない）→
  `completer.complete()` → `Future` を待って再確認。
- **期待結果**: 完了前（同期区間内）は `isSubmitting=true`、`completer.complete()` 後に `Future` を待つと `isSubmitting=false`。

### テストケース12: 保存が isSubmitting 中にもう一度呼ばれた場合、二重送信されない
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: テストケース11と同様に `Completer` で保存中の状態を作る。
- **入力値・テスト条件**: `isSubmitting=true` の間（マクロタスクを挟まない同一同期区間内）に再度 `answer(isCorrect: true)` を呼ぶ。
- **操作手順**: 1回目の `answer()` を保留したまま（`Future.delayed` を挟まずに）2回目を呼び、`completer.complete()` 後に両方を待つ。
- **期待結果**: `FakeSaveFlashcardResultUseCase.callCount` が `1` のまま（ガード条件 `state.isSubmitting` で早期return）。

### テストケース13: 保存に失敗した場合（ネットワーク）、errorMessage が設定され終了状態にならない
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: 単語1件で `start()`。`FakeSaveFlashcardResultUseCase` は `Left(Failure.network())` を返す。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: `await notifier.answer(isCorrect: true)`。
- **期待結果**: `isFinished=false`, `isSubmitting=false`, `errorMessage='通信エラーが発生しました'`。

### テストケース14: 保存に失敗した場合（認証）、認証エラーメッセージが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: 単語1件で `start()`。`Left(Failure.auth())` を返す。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: `await notifier.answer(isCorrect: true)`。
- **期待結果**: `errorMessage='認証エラーが発生しました'`。

### テストケース15: 保存に失敗した場合（データ未検出）、未検出エラーメッセージが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: 単語1件で `start()`。`Left(Failure.notFound())` を返す。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: `await notifier.answer(isCorrect: true)`。
- **期待結果**: `errorMessage='データが見つかりません'`。

### テストケース16: 保存に失敗した場合（不明なエラー）、詳細メッセージ付きのエラーが設定される
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: 単語1件で `start()`。`Left(Failure.unknown('boom'))` を返す。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: `await notifier.answer(isCorrect: true)`。
- **期待結果**: `errorMessage='エラーが発生しました: boom'`。

### テストケース17: 開始前に呼び出した場合、UseCase は呼ばれず state は変化しない
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: `start()` 未呼び出し。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: 呼び出し前後の state を比較。
- **期待結果**: `FakeSaveFlashcardResultUseCase.callCount=0`、state は変化しない（ガード条件 `!state.isStarted`）。

### テストケース18: 終了済みの場合、UseCase は呼ばれず state は変化しない
- **カテゴリ**: 異常系
- **対象メソッド**: answer()
- **事前条件**: 単語0件で `start()` し、`isFinished=true` の状態。
- **入力値・テスト条件**: `answer(isCorrect: true)`。
- **操作手順**: 呼び出し前後の state を比較。
- **期待結果**: `FakeSaveFlashcardResultUseCase.callCount=0`、state は変化しない（ガード条件 `state.isFinished`）。

## 対象外

なし（全行がテストで到達可能なロジックのため、対象外として除外する行は無い）。
