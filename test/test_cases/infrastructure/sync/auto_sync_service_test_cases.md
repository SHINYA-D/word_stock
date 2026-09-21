# auto_sync_service_test_cases.md

## 対象クラス / メソッド

| 項目 | 値 |
|------|-----|
| ファイルパス | lib/infrastructure/sync/auto_sync_service.dart |
| クラス名 | AutoSyncService |
| テスト対象メソッド | start() / stop() |

## 実行環境について

`AutoSyncService` は `ConnectivityMonitor`（インターフェース）と `SyncService`（具象クラス）に
依存する。以下の方針で Dart Pure Test として実行できるようにしている。

- **ConnectivityMonitor**: `test/helpers/fake_infrastructure.dart` の `FakeConnectivityMonitor`
  （単発イベントのみ流せる）に加え、複数回の状態変化を時系列で発火させたいケースのために、
  本テストファイル内に `StreamController` ベースの `ControllableConnectivityMonitor` を定義した。
- **SyncService**: インターフェースではなく具象クラスであり、コンストラクタが
  `SyncQueueDataSource` / `FirebaseFirestore` / `DatabaseHelper` を要求するため、
  `fake_cloud_firestore` の `FakeFirebaseFirestore` と実 `DatabaseHelper`（シングルトン、
  実際の DB アクセスは行わせない）で型要件のみ満たし、`syncLocalToRemote()` をオーバーライドして
  呼び出し回数・引数を記録する `FakeSyncService`（本テストファイル内に定義）を使用する。

## テストケース一覧

| # | テスト名 | カテゴリ | 対象メソッド | 状態 |
|---|---------|---------|-----------|------|
| 1 | オンライン状態への変化を検知した場合、SyncService.syncLocalToRemoteが呼ばれる | 正常系 | start() | ✅ |
| 2 | オフライン状態の通知を受けた場合、SyncService.syncLocalToRemoteは呼ばれない | 異常系 | start() | ✅ |
| 3 | オフライン→オンラインと複数回状態が変化した場合、オンラインになった回数分だけsyncLocalToRemoteが呼ばれる | 境界値 | start() | ✅ |
| 4 | startを2回連続で呼んだ場合、古い購読が解除され通知は二重に処理されない | 境界値 | start() | ✅ |
| 5 | stopを呼んだ後は、オンライン通知が来てもsyncLocalToRemoteは呼ばれない | 正常系 | stop() | ✅ |
| 6 | startされていない状態でstopを呼んでも例外は発生しない | 境界値 | stop() | ✅ |

## テストケース詳細

### テストケース1: オンライン状態への変化を検知した場合、SyncService.syncLocalToRemoteが呼ばれる
- **カテゴリ**: 正常系
- **対象メソッド**: start()
- **事前条件**: `FakeConnectivityMonitor(online: true)`（`onStatusChanged()` は生成時点の状態を1件だけ流す）
- **入力値・テスト条件**: `AutoSyncService.start()` を呼び出す
- **操作手順**: `start()` 実行後、マイクロタスクの完了を待つ
- **期待結果**: `FakeSyncService.syncLocalToRemoteCallCount` が1になり、渡された `connectivityMonitor` 引数が元の `monitor` インスタンスと一致する

### テストケース2: オフライン状態の通知を受けた場合、SyncService.syncLocalToRemoteは呼ばれない
- **カテゴリ**: 異常系
- **対象メソッド**: start()
- **事前条件**: `ControllableConnectivityMonitor` を使用
- **入力値・テスト条件**: `start()` 後に `monitor.emit(false)` でオフライン通知を送る
- **操作手順**: `start()` → `emit(false)` → マイクロタスク完了待ち
- **期待結果**: `syncLocalToRemoteCallCount` は0のまま

### テストケース3: オフライン→オンラインと複数回状態が変化した場合、オンラインになった回数分だけsyncLocalToRemoteが呼ばれる
- **カテゴリ**: 境界値
- **対象メソッド**: start()
- **事前条件**: `ControllableConnectivityMonitor` を使用
- **入力値・テスト条件**: `false → true → false → true` の順に4回状態を発火させる
- **操作手順**: 各 `emit` の後にマイクロタスクの完了を待ってから次の `emit` を行う
- **期待結果**: オンラインへの遷移が2回であるため `syncLocalToRemoteCallCount` は2

### テストケース4: startを2回連続で呼んだ場合、古い購読が解除され通知は二重に処理されない
- **カテゴリ**: 境界値
- **対象メソッド**: start()
- **事前条件**: `ControllableConnectivityMonitor` を使用
- **入力値・テスト条件**: `start()` を連続で2回呼んだ後に `emit(true)` を1回発火させる
- **操作手順**: `start(); start(); monitor.emit(true);` 実行後マイクロタスク完了待ち
- **期待結果**: 1回目の `start()` で張られた購読は `_subscription?.cancel()` により解除されているため、`syncLocalToRemoteCallCount` は1（2にならない＝二重購読が発生していない）

### テストケース5: stopを呼んだ後は、オンライン通知が来てもsyncLocalToRemoteは呼ばれない
- **カテゴリ**: 正常系
- **対象メソッド**: stop()
- **事前条件**: `ControllableConnectivityMonitor` を使用し `start()` 済み
- **入力値・テスト条件**: `stop()` 実行後に `monitor.emit(true)` を発火させる
- **操作手順**: `start(); stop(); monitor.emit(true);` 実行後マイクロタスク完了待ち
- **期待結果**: 購読が解除済みのため `syncLocalToRemoteCallCount` は0のまま

### テストケース6: startされていない状態でstopを呼んでも例外は発生しない
- **カテゴリ**: 境界値
- **対象メソッド**: stop()
- **事前条件**: `AutoSyncService` を生成しただけで `start()` は未実行（`_subscription` は初期値 `null`）
- **入力値・テスト条件**: `stop()` を直接呼ぶ
- **操作手順**: `stop()` 呼び出しのみ
- **期待結果**: `null?.cancel()` は無害であり、例外を投げず正常終了する（`returnsNormally`）

## 対象外

なし。`lib/infrastructure/sync/auto_sync_service.dart` は全32行が上記6ケースの組み合わせで到達可能であり、
到達不能・防御的コードは存在しない。
