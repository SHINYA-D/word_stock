---
name: build-runner-flow
description: WordStockでFreezedのエンティティ(*.freezed.dart)やRiverpodのProvider(*.g.dart, router.g.dart)のソースを追加・変更した直後に、build_runnerでコード生成を実行したいときに使う。「コード生成して」「build_runner回して」等の依頼や、Freezed/Riverpod関連ファイル編集後の流れで発火する。
---

# build_runner 実行フロー

Freezed / Riverpod のコード生成をこの会話の中でそのまま実行し、結果を確認するための手順。

## 前提(CLAUDE.mdより)

- 素の `dart run` ではなく必ず `fvm dart run` を使う(このプロジェクトはFVMでバージョン固定されているため)
- `*.freezed.dart` / `*.g.dart` / `router.g.dart` は生成ファイル。手で編集しない

## 手順

1. 次のコマンドを実行する
   ```bash
   fvm dart run build_runner build --delete-conflicting-outputs
   ```
2. 出力を確認し、次のいずれかに分類する
   - **成功**: 生成/更新/削除されたファイル一覧をユーザーに報告する
   - **コンフリクト警告**: `--delete-conflicting-outputs` により自動解決されたものはその旨を報告する
   - **ビルドエラー**: エラーメッセージからソースコード側の問題(型不整合、アノテーション記述ミス、Freezed 3.x構文違反など)を特定する
3. エラーがある場合、原因箇所を Read / Grep で確認して具体的に説明する。ただし修正コードの適用はユーザーの意向を確認してから行う(生成コマンドの実行自体が目的であり、無断でソースを書き換えない)

## 出力形式

```
実行結果: 成功 / エラー
生成/更新/削除されたファイル: (該当する場合)
エラー内容: (該当する場合、ファイルパス:行番号を含めて)
原因の推定: (該当する場合)
推奨される対応: (該当する場合、コードは書かず説明のみ)
```

---

補足: このSkillは `.claude/agents/codegen-runner.md` (Sub Agent) と同じドメイン知識を持つが、独立したコンテキストを新規に立ち上げず、**今のこの会話の中**でそのまま手順を実行する点が異なる。ちょっとしたコード生成 1 回で済むときはこちらのSkillが軽量。診断が長引きそうな複雑なエラー調査を任せて会話のコンテキストを汚したくない場合は、代わりに `codegen-runner` Sub Agentを呼ぶとよい。
