# ShellPage Widget テスト項目書

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/presentation/shell/shell_page.dart |
| クラス名 | ShellPage |
| テスト対象メソッド | build() / _tabIndex() |

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | 3つのナビゲーション項目（ホーム・成績・設定）が表示される場合、NavigationBarにすべてのラベルが表示される | 正常系 | build() | ✅ |
| 2 | /home表示時、ホームタブが選択状態になる | 正常系 | build() | ✅ |
| 3 | /folder/:idのようなホーム配下のサブパス表示時、ホームタブが選択状態になる | 境界値 | _tabIndex() | ✅ |
| 4 | 成績タブをタップした場合、/results画面に切り替わりタブの選択状態も更新される | 正常系 | build() | ✅ |
| 5 | 設定タブをタップした場合、/settings画面に切り替わりタブの選択状態も更新される | 正常系 | build() | ✅ |

## テストケース詳細

### テストケース1: 3つのナビゲーション項目（ホーム・成績・設定）が表示される場合、NavigationBarにすべてのラベルが表示される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: テスト専用の最小GoRouter（/home, /folder/:id, /results, /settingsをShellRoute配下に定義）で `/home` を初期表示
- **入力値・テスト条件**: なし（初期描画のみ）
- **操作手順**: `MaterialApp.router` をpumpする
- **期待結果**: `find.text('ホーム')` `find.text('成績')` `find.text('設定')` がそれぞれ1件見つかる。`NavigationBar` が1件見つかる

### テストケース2: /home表示時、ホームタブが選択状態になる
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 初期ロケーションを `/home` にしてGoRouterを構築
- **入力値・テスト条件**: なし
- **操作手順**: pumpWidgetのみ
- **期待結果**: `NavigationBar.selectedIndex == 0`。子画面として `home-screen` のテキストが表示される

### テストケース3: /folder/:idのようなホーム配下のサブパス表示時、ホームタブが選択状態になる
- **カテゴリ**: 境界値
- **対象メソッド**: _tabIndex()
- **事前条件**: 初期ロケーションを `/folder/folder-1` にしてGoRouterを構築
- **入力値・テスト条件**: `location = '/folder/folder-1'`（`_tabs`のどの要素とも完全一致しないがホームのプレフィックスに一致するケース）
- **操作手順**: pumpWidgetのみ
- **期待結果**: `NavigationBar.selectedIndex == 0`（ホームタブが選択される）。子画面として `folder-screen` が表示される

### テストケース4: 成績タブをタップした場合、/results画面に切り替わりタブの選択状態も更新される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 初期ロケーション `/home` でGoRouterを構築
- **入力値・テスト条件**: なし
- **操作手順**: `find.text('成績')` をtap → `pumpAndSettle()`
- **期待結果**: `results-screen` のテキストが表示される。`NavigationBar.selectedIndex == 1`

### テストケース5: 設定タブをタップした場合、/settings画面に切り替わりタブの選択状態も更新される
- **カテゴリ**: 正常系
- **対象メソッド**: build()
- **事前条件**: 初期ロケーション `/home` でGoRouterを構築
- **入力値・テスト条件**: なし
- **操作手順**: `find.text('設定')` をtap → `pumpAndSettle()`
- **期待結果**: `settings-screen` のテキストが表示される。`NavigationBar.selectedIndex == 2`

## 対象外

- なし（48行のシェルWidget。build()とプライベートメソッド_tabIndex()の分岐は全ケースで到達）
