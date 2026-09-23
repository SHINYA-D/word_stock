---
name: widget-test-authoring
description: WordStockでPresentation層のPage（*_page.dart）のWidgetテスト（testWidgets()）を書くときの作法・雛形集。buildWithMockRepositories()の使い方、ViewModelサブクラスoverrideでのloading/success/error注入、pump/pumpAndSettleの使い分け。Widgetテストの新規作成・修正時に参照する。
---

# Widgetテストの書き方（WordStock）

CLAUDE.md「## テスト方針」の実装ガイド。`testWidgets()` を使い、
**「描画されるか」「操作で期待どおり反応するか」** だけを見る。ロジック網羅は ViewModel 単体テストの担当。

## 基本形

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_helpers.dart';

void main() {
  testWidgets('一覧が取得できたとき、単語カードが件数分表示される', (tester) async {
    await tester.pumpWidget(buildWithMockRepositories(
      child: const WordListPage(folderId: 'folder-1'),
      extra: [wordListViewModelProvider.overrideWith(_WordListSuccess.new)],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNWidgets(3));
  });
}
```

## `buildWithMockRepositories`（test/helpers/test_helpers.dart）

```dart
Widget buildWithMockRepositories({required Widget child, List<Override> extra = const []})
```

- auth / folder / word / settings / flashcardResult の Mock Repository と `currentUserProvider = testUser` を
  override 済みの `ProviderScope + MaterialApp(home: child)` を返す
- 画面固有の ViewModel 状態は `extra:` に override を渡して注入する
- フィクスチャ: `testUser` / `testFolders`（2件）/ `testWords`（apple/banana/cherry の3件）

## ViewModel 状態サブクラス（テストファイル内に定義）

```dart
class _ResultViewModelLoading extends ResultViewModel {
  @override
  FutureOr<ResultState> build() => const ResultState.loading();
}
class _ResultViewModelSuccess extends ResultViewModel {
  @override
  FutureOr<ResultState> build() => ResultState.success(results: testResults);
}
class _ResultViewModelError extends ResultViewModel {
  @override
  FutureOr<ResultState> build() => const ResultState.error(message: 'エラー');
}
```

- override は `provider.overrideWith(_ResultViewModelLoading.new)`
- 状態型・provider 名は対象 Page が `ref.watch(...)` している provider と、その `*.g.dart` で確認
- コンストラクタに依存（UseCase 等）がある ViewModel は、サブクラスの `super(...)` にダミーを渡すか
  `build()` だけ override すれば依存は使われないので不要なことが多い

## pump の使い分け

| 状況 | 使う |
|------|------|
| 同期的な1フレーム描画 | `await tester.pump()` |
| 非同期 build（Future 完了待ち）・アニメーション・画面遷移後 | `await tester.pumpAndSettle()` |
| 特定時間の経過 | `await tester.pump(const Duration(milliseconds: 300))` |

`pumpAndSettle` が無限ループ（永久アニメーション）でタイムアウトする場合は `pump` を複数回。

## 検証の道具

- `find.byType(X)` / `find.text('...')` / `find.byKey(const Key('...'))` / `find.byIcon(Icons.add)`
- `findsOneWidget` / `findsNothing` / `findsNWidgets(n)` / `findsWidgets`
- 操作: `await tester.tap(find.byKey(...)); await tester.pumpAndSettle();`
- 入力: `await tester.enterText(find.byType(TextField).first, 'apple');`
- ダイアログ: タップ後 `expect(find.byType(AlertDialog), findsOneWidget)` / `find.text('ネットワークエラー')`
- 遷移: go_router 使用。遷移先 Page の Widget が出るかで確認（`expect(find.byType(NextPage), findsOneWidget)`）

## シナリオの型

1. **Loading** … `CircularProgressIndicator` が出る
2. **Success** … 期待の一覧 / テキスト / 件数、空データ時の空表示
3. **Error** … エラー表示（`ErrorScreen` / `NetworkErrorDialog` / SnackBar）
4. **ユーザー操作** … ボタン→遷移 / FAB→ダイアログ / スワイプ削除→確認ダイアログ など

## やらないこと

- ピクセル単位のレイアウト検証、色・フォント検証
- ViewModel のロジック分岐網羅（`result.fold` の全 Failure 種別など）→ 単体テストへ
- `mockito` / `mocktail`

## 実行

```bash
bash scripts/test_harness.sh test/presentation/<...>_page_test.dart
```
Page 本体は限定分母外なのでカバレッジ数値は参考。**全 green** が合格条件。
