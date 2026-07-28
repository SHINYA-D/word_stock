# オフライン同期機能 実装要件定義書（v2）

## このドキュメントについて

本ドキュメントはWordStockにオフライン同期機能を追加するための実装指示書です。
Claude Code（VS Code拡張）がこのドキュメントを読み込んで段階的に実装することを前提に作成されています。

**実装ルール**
- フェーズは順番に実装すること。前のフェーズが完了していない状態で次に進まない
- 各フェーズ完了時にコミット＆PRを作成すること
- 既存のクリーンアーキテクチャ（presentation / application / domain / infrastructure）を厳守すること
- 既存のRiverpod + Freezed + riverpod_generatorパターンに従うこと
- エラーハンドリングを怠らないこと
- SQLiteの複数操作は必ずトランザクションで囲むこと
- 各フェーズの「完了条件」をすべて満たしてから次のフェーズに進むこと

---

## 背景と目的

### 背景
WordStockは現在オンライン専用アプリで、ネットワーク環境外では動作しない。
ポートフォリオとして技術的な深さを示すため、オフライン対応を追加する。

### 目的
- ユーザーがネットワーク環境外でもアプリを継続利用できるようにする
- オンライン復帰時にデータを自動同期する
- 複数端末利用時のデータ不整合を解消する

### スコープ
- オフライン対応：フォルダ・単語・テスト結果・設定の登録/更新/削除
- オフライン対象外：ログイン・新規アカウント登録・パスワード変更（Firebase Auth依存のため）

---

## 既存プロジェクト構造

```
lib/
├── app.dart
├── main.dart
├── firebase_options.dart
├── application/
│   └── use_cases/
│       ├── auth/
│       ├── folder/
│       ├── settings/
│       ├── test_result/
│       └── word/
├── core/
│   ├── di/              # Riverpod Provider（riverpod_generator使用）
│   ├── error/
│   ├── router/
│   ├── theme/
│   └── widgets/
├── domain/
│   ├── entities/        # Freezedモデル
│   └── repositories/    # Repository interface
├── infrastructure/
│   ├── data_sources/
│   │   ├── firebase_auth_data_source.dart
│   │   └── firestore_data_source.dart
│   └── repositories/
│       ├── auth_repository_impl.dart
│       ├── folder_repository_impl.dart
│       ├── settings_repository_impl.dart
│       ├── test_result_repository_impl.dart
│       ├── word_repository_impl.dart
│       └── mock/
└── presentation/
```

### 今回追加するファイル配置

```
lib/
├── core/
│   └── firebase/                              # 新規フォルダ
│       └── firestore_path.dart                # 新規
└── infrastructure/
    ├── data_sources/
    │   ├── local/                             # 新規フォルダ
    │   │   ├── database_helper.dart           # 新規
    │   │   ├── tables/                        # 新規フォルダ
    │   │   │   ├── folder_table.dart
    │   │   │   ├── word_table.dart
    │   │   │   ├── test_result_table.dart
    │   │   │   ├── settings_table.dart
    │   │   │   ├── sync_queue_table.dart
    │   │   │   └── sync_meta_table.dart
    │   │   ├── folder_local_data_source.dart
    │   │   ├── word_local_data_source.dart
    │   │   ├── test_result_local_data_source.dart
    │   │   ├── settings_local_data_source.dart
    │   │   └── sync_queue_data_source.dart
    │   └── network/                           # 新規フォルダ
    │       └── connectivity_monitor.dart      # 新規
    └── sync/                                  # 新規フォルダ
        ├── sync_service.dart                  # 新規
        └── auto_sync_service.dart             # 新規
```

---

## 全体アーキテクチャ

### データの流れ

| 状態 | 書き込み先 | 読み取り元 |
|------|-----------|-----------|
| オンライン時 | Firestore + SQLite（両方） | SQLite |
| オフライン時 | SQLite のみ（キューに記録） | SQLite |
| オンライン復帰時 | キューからFirestoreに同期 | SQLite |

**重要：読み取りは常にSQLiteから行う**
UI側はオン/オフラインを意識しない設計にする。

### 同期トリガー

**ローカル→リモート**
- オフライン→オンライン復帰時：connectivity_plusでネットワーク変化を検知

**リモート→ローカル**
- ログイン成功時：Firestoreから全データ取得（初回・再インストール対応）
- resumed時：インターバル付き差分取得（前回同期から5分以上経過時のみ）

---

## Firestoreコレクション構成

サブコレクション構成を採用している。

```
users/{userId}/folders/{folderId}
users/{userId}/folders/{folderId}/words/{wordId}
users/{userId}/test_results/{testResultId}
users/{userId}/settings
```

---

## DateTime型の扱い（重要）

### 原則

| 層 | DateTime型の扱い |
|----|-----------------|
| presentation / application / domain | DateTime型で扱う |
| infrastructure/repositories | DateTime型で扱う |
| infrastructure/data_sources/local | SQLiteではString型（ISO8601）、モデルへの変換時にDateTime型に戻す |
| infrastructure/data_sources（Firestore） | DateTime型のまま渡す（Firestoreが自動でTimestampに変換） |
| sync_queueのpayload | ISO8601文字列としてJSON化、同期時にDateTimeに戻す |

### 変換責任の集約

**LocalDataSourceが変換責任を持つ。**
Repository層より上はSQLiteの実装詳細を気にせず、常にDateTime型で扱う。

```dart
// LocalDataSourceでの変換例
Word _toWord(Map<String, dynamic> row) {
  return Word(
    id: row['id'] as String,
    front: row['front'] as String,
    back: row['back'] as String,
    createdAt: DateTime.parse(row['createdAt'] as String),  // String → DateTime
    updatedAt: DateTime.parse(row['updatedAt'] as String),  // String → DateTime
  );
}

Map<String, dynamic> _toRow(Word word, {required String userId, required String folderId, String syncStatus = 'synced'}) {
  return {
    'id': word.id,
    'front': word.front,
    'back': word.back,
    'folderId': folderId,
    'userId': userId,
    'createdAt': word.createdAt.toIso8601String(),  // DateTime → String
    'updatedAt': word.updatedAt.toIso8601String(),  // DateTime → String
    'syncStatus': syncStatus,
  };
}
```

### Firestoreへの送信時

```dart
// モデルのDateTime型をそのまま渡す
await firestore.doc(path).set({
  'front': word.front,
  'back': word.back,
  'createdAt': word.createdAt,  // DateTime型のまま（Firestoreが自動変換）
  'updatedAt': word.updatedAt,  // DateTime型のまま
});
```

### sync_queueのpayloadでの扱い

jsonEncodeはDateTime型を扱えないため、payload内ではISO8601文字列として保存する。

```dart
// キュー登録時
final payloadMap = {
  'front': word.front,
  'back': word.back,
  'createdAt': word.createdAt.toIso8601String(),  // String化
  'updatedAt': word.updatedAt.toIso8601String(),  // String化
};
await db.insert('sync_queue', {
  'payload': jsonEncode(payloadMap),
  // ...
});

// 同期時に取り出してFirestoreに送る
final decoded = jsonDecode(record['payload'] as String) as Map<String, dynamic>;
final firestoreData = {
  'front': decoded['front'],
  'back': decoded['back'],
  'createdAt': DateTime.parse(decoded['createdAt'] as String),  // DateTime化
  'updatedAt': DateTime.parse(decoded['updatedAt'] as String),  // DateTime化
};
await firestore.doc(path).set(firestoreData);
```

---

## SQLiteトランザクションのルール

### 必ずトランザクションで囲むべき場面

1. **データテーブルへの書き込み + sync_queueへの登録**
   ```dart
   await db.transaction((txn) async {
     await txn.insert('words', wordRow);
     await txn.insert('sync_queue', queueRow);
   });
   ```
   片方だけ成功して片方が失敗するとデータ不整合が起きるため。

2. **リモート→ローカルの一括UPSERT**
   Firestoreから取得した複数のレコードをSQLiteに反映するとき。

3. **キュー処理中のステータス更新**
   （キュー同期自体はトランザクションなし。Firestore通信を挟むため）

### トランザクションを使わない場面

1. **キューの同期処理（ローカル→リモート）**
   Firestore通信を挟むため、SQLiteトランザクションで囲むとロック時間が長くなる。
   1件ずつ処理して成功分だけキューから削除する方式にする。

---

## Firestoreトランザクションとは

Firestoreトランザクションは、「ドキュメントを読み取って、その内容を元に書き込む」という
一連の処理をアトミックに実行する仕組み。

### 競合解決で使用する

ローカル→リモート同期時に、Firestore側のupdatedAtを読み取ってローカルと比較し、
ローカルの方が新しい場合のみ書き込む。その読み取りと書き込みの間に別の端末の
更新が割り込むことを防ぐため、Firestoreトランザクションを使用する。

```dart
await _firestore.runTransaction((transaction) async {
  final docRef = _firestore.doc(path);
  final docSnapshot = await transaction.get(docRef);

  if (docSnapshot.exists) {
    final remoteUpdatedAt = (docSnapshot.data()!['updatedAt'] as Timestamp).toDate();
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      // リモートの方が新しいのでスキップ
      return;
    }
  }

  transaction.set(docRef, data);
});
```

Firestoreトランザクションは、読み取ったドキュメントが他の処理で書き換えられていないことを
保証する。もし途中で他の処理が割り込んだ場合、Firestoreは自動でトランザクション全体を
リトライしてくれる。

---

## フェーズ1：基盤準備

### タスク1-1：既存モデルにupdatedAtを追加

**対象ファイル**
- `lib/domain/entities/word.dart`
- `lib/domain/entities/folder.dart`
- `lib/domain/entities/test_result.dart`
- `lib/domain/entities/user_settings.dart`

**実装内容**

既存のFreezedモデルに`updatedAt`フィールドを追加する。

```dart
@freezed
abstract class Word with _$Word {
  const factory Word({
    required String id,
    required String front,
    required String back,
    required DateTime createdAt,
    required DateTime updatedAt,  // ← 追加
  }) = _Word;
}
```

**各モデルへの追加方針**
- Word：`updatedAt`を追加
- Folder：`updatedAt`を追加
- TestResult：`updatedAt`を追加
- UserSettings：`updatedAt`を追加

Freezedの再生成を忘れずに行う。
```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### タスク1-2：FirestorePathクラスを作成

**対象ファイル**
- `lib/core/firebase/firestore_path.dart`（新規作成）

**実装内容**

```dart
class FirestorePath {
  // --- folders ---
  static String folders(String userId) =>
      'users/$userId/folders';

  static String folder(String userId, String folderId) =>
      'users/$userId/folders/$folderId';

  // --- words ---
  static String words(String userId, String folderId) =>
      'users/$userId/folders/$folderId/words';

  static String word(String userId, String folderId, String wordId) =>
      'users/$userId/folders/$folderId/words/$wordId';

  // --- test_results ---
  static String testResults(String userId) =>
      'users/$userId/test_results';

  static String testResult(String userId, String testResultId) =>
      'users/$userId/test_results/$testResultId';

  // --- settings ---
  static String settings(String userId) =>
      'users/$userId/settings';
}
```

### フェーズ1の完了条件
- [ ] 全モデルにupdatedAtが追加されている
- [ ] Freezedの再生成が完了している
- [ ] FirestorePathクラスが作成され、全パスメソッドが実装されている
- [ ] ビルドが通る

---

## フェーズ2：SQLiteテーブル定義（分離設計）

### 設計方針

DatabaseHelperは「どのテーブルがあるか」を知らなくてよい。
各テーブルファイルが自分自身のCREATE文を管理し、DatabaseHelperはそれを呼び出すだけ。

この設計の利点：
- テーブルが増えたときにDatabaseHelperを触らずに済む
- 各テーブルの定義が1ファイルに集約されて見つけやすい
- CREATE文とCRUDメソッドを同じファイル内に置ける

### タスク2-1：pubspec.yamlにパッケージを追加

```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.0
  connectivity_plus: ^5.0.0
```

### タスク2-2：各テーブルクラスを作成

**対象ファイル**
- `lib/infrastructure/data_sources/local/tables/folder_table.dart`
- `lib/infrastructure/data_sources/local/tables/word_table.dart`
- `lib/infrastructure/data_sources/local/tables/test_result_table.dart`
- `lib/infrastructure/data_sources/local/tables/settings_table.dart`
- `lib/infrastructure/data_sources/local/tables/sync_queue_table.dart`
- `lib/infrastructure/data_sources/local/tables/sync_meta_table.dart`

**実装テンプレート**

各テーブルクラスは以下の責務を持つ。
- テーブル名の定数定義
- CREATE文の実行メソッド `onCreate(Database db)`
- 将来のマイグレーション用メソッド（必要に応じて）

**folder_table.dart の実装例**

```dart
import 'package:sqflite/sqflite.dart';

class FolderTable {
  static const String tableName = 'folders';

  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parentFolderId TEXT,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }
}
```

**word_table.dart の実装例**

```dart
class WordTable {
  static const String tableName = 'words';

  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        folderId TEXT NOT NULL,
        userId TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }
}
```

**test_result_table.dart**

```dart
class TestResultTable {
  static const String tableName = 'test_results';

  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        folderId TEXT NOT NULL,
        totalCount INTEGER NOT NULL,
        correctCount INTEGER NOT NULL,
        date TEXT NOT NULL,
        userId TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }
}
```

**settings_table.dart**

```dart
class SettingsTable {
  static const String tableName = 'settings';

  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        userId TEXT PRIMARY KEY,
        colorTheme TEXT NOT NULL DEFAULT 'indigo',
        darkMode INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');
  }
}
```

**sync_queue_table.dart**

```dart
class SyncQueueTable {
  static const String tableName = 'sync_queue';

  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        parent_id TEXT,
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }
}
```

**sync_meta_table.dart**

```dart
class SyncMetaTable {
  static const String tableName = 'sync_meta';

  static Future<void> onCreate(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
```

### タスク2-3：DatabaseHelperを作成

**対象ファイル**
- `lib/infrastructure/data_sources/local/database_helper.dart`

**実装内容**

DatabaseHelperは各テーブルクラスのonCreateを呼び出すだけ。

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tables/folder_table.dart';
import 'tables/word_table.dart';
import 'tables/test_result_table.dart';
import 'tables/settings_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/sync_meta_table.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _dbName = 'wordstock.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // トランザクションで全テーブルを作成
    // 途中で失敗した場合、すべてロールバックする
    await db.transaction((txn) async {
      await FolderTable.onCreate(txn);
      await WordTable.onCreate(txn);
      await TestResultTable.onCreate(txn);
      await SettingsTable.onCreate(txn);
      await SyncQueueTable.onCreate(txn);
      await SyncMetaTable.onCreate(txn);
    });
  }
}
```

**注意**：`db.transaction`の中では`Database`ではなく`Transaction`が渡される。
各テーブルの`onCreate`は`Database`と`Transaction`の共通インターフェースである
`DatabaseExecutor`を受け取るように型を調整するか、Transaction型で受けるように実装する。

### フェーズ2の完了条件
- [ ] 6つのテーブルクラスが実装されている
- [ ] DatabaseHelperが実装され、各テーブルクラスのonCreateを呼び出している
- [ ] テーブル作成がトランザクション内で実行されている
- [ ] 初回起動時にテーブルが正常に作成されることを確認している
- [ ] ビルドが通る

---

## フェーズ3：LocalDataSourceとsync_queueの実装

### タスク3-1：各データテーブルのLocalDataSourceを作成

**対象ファイル**
- `lib/infrastructure/data_sources/local/folder_local_data_source.dart`
- `lib/infrastructure/data_sources/local/word_local_data_source.dart`
- `lib/infrastructure/data_sources/local/test_result_local_data_source.dart`
- `lib/infrastructure/data_sources/local/settings_local_data_source.dart`

**実装内容**

各LocalDataSourceは以下の責務を持つ。
- モデル ↔ SQLite行の変換（DateTime ↔ String）
- CRUD操作（insert / update / delete / findById / findAll / upsert）
- syncStatusの管理

**word_local_data_source.dart の実装例**

```dart
import 'package:sqflite/sqflite.dart';
import 'package:wordstock/domain/entities/word.dart';
import 'database_helper.dart';
import 'tables/word_table.dart';

class WordLocalDataSource {
  final DatabaseHelper _dbHelper;

  WordLocalDataSource(this._dbHelper);

  // モデル → SQLite行
  Map<String, dynamic> _toRow(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) {
    return {
      'id': word.id,
      'front': word.front,
      'back': word.back,
      'folderId': folderId,
      'userId': userId,
      'createdAt': word.createdAt.toIso8601String(),
      'updatedAt': word.updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  // SQLite行 → モデル
  Word _toWord(Map<String, dynamic> row) {
    return Word(
      id: row['id'] as String,
      front: row['front'] as String,
      back: row['back'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> insert(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(
    Word word, {
    required String userId,
    required String folderId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId, syncStatus: syncStatus),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<void> delete(String wordId) async {
    final db = await _dbHelper.database;
    await db.delete(
      WordTable.tableName,
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<Word?> findById(String wordId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      WordTable.tableName,
      where: 'id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toWord(rows.first);
  }

  Future<List<Word>> findByFolderId(String folderId, {required String userId}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      WordTable.tableName,
      where: 'folderId = ? AND userId = ?',
      whereArgs: [folderId, userId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(_toWord).toList();
  }

  Future<void> upsert(
    Word word, {
    required String userId,
    required String folderId,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      WordTable.tableName,
      _toRow(word, userId: userId, folderId: folderId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

他のLocalDataSource（folder / test_result / settings）も同様のパターンで実装する。

### タスク3-2：SyncQueueDataSourceを作成

**対象ファイル**
- `lib/infrastructure/data_sources/local/sync_queue_data_source.dart`

**実装内容**

```dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'tables/sync_queue_table.dart';

class SyncQueueDataSource {
  final DatabaseHelper _dbHelper;

  SyncQueueDataSource(this._dbHelper);

  // キューに追加（単体使用時）
  Future<void> enqueue({
    required String operation,
    required String tableName,
    required String recordId,
    String? parentId,
    Map<String, dynamic>? payload,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(SyncQueueTable.tableName, {
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'parent_id': parentId,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // トランザクション内でキューに追加（データ書き込みと同時実行時に使用）
  Future<void> enqueueInTransaction(
    Transaction txn, {
    required String operation,
    required String tableName,
    required String recordId,
    String? parentId,
    Map<String, dynamic>? payload,
  }) async {
    await txn.insert(SyncQueueTable.tableName, {
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'parent_id': parentId,
      'payload': payload != null ? jsonEncode(payload) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // キューから古い順に全件取得
  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _dbHelper.database;
    return await db.query(SyncQueueTable.tableName, orderBy: 'created_at ASC');
  }

  // 特定のキューを削除（同期成功時）
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete(SyncQueueTable.tableName, where: 'id = ?', whereArgs: [id]);
  }

  // キュー件数を取得
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ${SyncQueueTable.tableName}');
    return result.first['count'] as int;
  }
}
```

### フェーズ3の完了条件
- [ ] 4つのLocalDataSourceが実装されている
- [ ] DateTime ↔ String の変換がLocalDataSource層で完結している
- [ ] SyncQueueDataSourceが実装されている
- [ ] enqueueInTransactionメソッドが用意されている
- [ ] 各DataSourceのCRUDが動作することを確認している

---

## フェーズ4：ネットワーク監視とオフライン書き込み対応

### タスク4-1：ConnectivityMonitorを作成

**対象ファイル**
- `lib/infrastructure/data_sources/network/connectivity_monitor.dart`

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityMonitor {
  final Connectivity _connectivity = Connectivity();

  // 現在オンラインかどうかを即座に確認
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ネットワーク状態の変化を監視
  Stream<bool> onStatusChanged() {
    return _connectivity.onConnectivityChanged.map((results) {
      return !results.contains(ConnectivityResult.none);
    });
  }
}
```

### タスク4-2：既存のRepositoryImplをオフライン対応に修正

**対象ファイル**
- `lib/infrastructure/repositories/folder_repository_impl.dart`
- `lib/infrastructure/repositories/word_repository_impl.dart`
- `lib/infrastructure/repositories/test_result_repository_impl.dart`
- `lib/infrastructure/repositories/settings_repository_impl.dart`

**実装内容**

書き込み処理（create/update/delete）をオン/オフライン対応に修正する。
**書き込みとsync_queue登録は必ずSQLiteトランザクション内で実行する。**

**word_repository_impl.dart の実装例**

```dart
class WordRepositoryImpl implements WordRepository {
  final WordLocalDataSource _localDataSource;
  final FirestoreDataSource _remoteDataSource;
  final SyncQueueDataSource _syncQueueDataSource;
  final DatabaseHelper _dbHelper;
  final ConnectivityMonitor _connectivityMonitor;
  final String Function() _getCurrentUserId;

  WordRepositoryImpl({
    required WordLocalDataSource localDataSource,
    required FirestoreDataSource remoteDataSource,
    required SyncQueueDataSource syncQueueDataSource,
    required DatabaseHelper dbHelper,
    required ConnectivityMonitor connectivityMonitor,
    required String Function() getCurrentUserId,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _syncQueueDataSource = syncQueueDataSource,
        _dbHelper = dbHelper,
        _connectivityMonitor = connectivityMonitor,
        _getCurrentUserId = getCurrentUserId;

  @override
  Future<void> createWord(Word word, String folderId) async {
    final userId = _getCurrentUserId();
    final isOnline = await _connectivityMonitor.isOnline();

    if (isOnline) {
      // オンライン時：SQLiteとFirestore両方に書き込み
      await _localDataSource.insert(
        word,
        userId: userId,
        folderId: folderId,
        syncStatus: 'synced',
      );
      await _remoteDataSource.createWord(word, userId, folderId);
    } else {
      // オフライン時：SQLiteとsync_queueをトランザクション内で同時書き込み
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // SQLiteに書き込み
        await txn.insert(
          WordTable.tableName,
          {
            'id': word.id,
            'front': word.front,
            'back': word.back,
            'folderId': folderId,
            'userId': userId,
            'createdAt': word.createdAt.toIso8601String(),
            'updatedAt': word.updatedAt.toIso8601String(),
            'syncStatus': 'pending',
          },
        );
        // キューに登録
        await _syncQueueDataSource.enqueueInTransaction(
          txn,
          operation: 'create',
          tableName: WordTable.tableName,
          recordId: word.id,
          parentId: folderId,
          payload: {
            'front': word.front,
            'back': word.back,
            'createdAt': word.createdAt.toIso8601String(),
            'updatedAt': word.updatedAt.toIso8601String(),
          },
        );
      });
    }
  }

  @override
  Future<List<Word>> getWordsByFolderId(String folderId) async {
    // 読み取りは常にSQLiteから
    final userId = _getCurrentUserId();
    return await _localDataSource.findByFolderId(folderId, userId: userId);
  }

  // update / delete も同様のパターンで実装する
  // 削除時のpayloadはnullでOK
}
```

**注意事項**
- オフライン時はSQLiteへの書き込みとsync_queueへの登録を必ず同じトランザクション内で実行する
- 読み取りは常にLocalDataSourceから
- オンライン時にFirestore書き込みが失敗した場合のリトライは、Phase7のエラーハンドリングで対応

### タスク4-3：Providerを追加

**対象ファイル**
- `lib/core/di/` 配下に新規ファイルを追加（既存のパターンに従う）
- `lib/core/di/local_data_source_providers.dart`（新規）
- `lib/core/di/sync_providers.dart`（新規）

既存のriverpod_generatorパターンに従って実装する。

### フェーズ4の完了条件
- [ ] ConnectivityMonitorが実装されている
- [ ] 4つのRepositoryImplがオン/オフライン対応に修正されている
- [ ] オフライン時の書き込みがトランザクション内で実行されている
- [ ] 必要なProviderが追加されている
- [ ] 機内モードで単語を作成→SQLiteに保存される、sync_queueに記録されることを確認している
- [ ] 機内モード解除→既存のデータはそのまま、新規書き込みはFirestoreに行くことを確認している

---

## フェーズ5：ローカル→リモート自動同期

### タスク5-1：SyncServiceを作成

**対象ファイル**
- `lib/infrastructure/sync/sync_service.dart`

**実装内容**

```dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wordstock/core/firebase/firestore_path.dart';
import 'package:wordstock/infrastructure/data_sources/local/sync_queue_data_source.dart';

class SyncService {
  final SyncQueueDataSource _syncQueueDataSource;
  final FirebaseFirestore _firestore;
  final String Function() _getCurrentUserId;

  SyncService({
    required SyncQueueDataSource syncQueueDataSource,
    required FirebaseFirestore firestore,
    required String Function() getCurrentUserId,
  })  : _syncQueueDataSource = syncQueueDataSource,
        _firestore = firestore,
        _getCurrentUserId = getCurrentUserId;

  /// ローカル→リモート同期
  /// キューから古い順に1件ずつ取り出してFirestoreに反映する
  ///
  /// エラーハンドリング方針:
  /// - 失敗した時点で同期を中断する
  /// - 次回の同期時にキューの先頭から再開するため、順序が完全に保たれる
  /// - 権限エラーは運用上ほぼ発生しない(ユーザーは自分のデータを操作するため)
  Future<void> syncLocalToRemote() async {
    final userId = _getCurrentUserId();
    final queueItems = await _syncQueueDataSource.getAll();

    for (final item in queueItems) {
      try {
        await _processQueueItem(item, userId);
        // 成功したらキューから削除
        await _syncQueueDataSource.delete(item['id'] as int);
      } catch (e) {
        // 失敗した時点で同期を中断
        // 次回の同期でキューの先頭から再開するので順序が保たれる
        break;
      }
    }
  }

  Future<void> _processQueueItem(
    Map<String, dynamic> item,
    String userId,
  ) async {
    final tableName = item['table_name'] as String;
    final recordId = item['record_id'] as String;
    final parentId = item['parent_id'] as String?;
    final operation = item['operation'] as String;
    final payloadStr = item['payload'] as String?;

    // パスを構築
    final path = _buildPath(tableName, userId, recordId, parentId);

    if (operation == 'delete') {
      await _firestore.doc(path).delete();
    } else {
      final decoded = jsonDecode(payloadStr!) as Map<String, dynamic>;
      final firestoreData = _convertToFirestoreData(decoded);
      await _firestore.doc(path).set(firestoreData);
    }
  }

  /// SQLiteに保存されていたJSON（DateTime型はString）を
  /// Firestoreに送る形式（DateTime型）に変換する
  Map<String, dynamic> _convertToFirestoreData(Map<String, dynamic> decoded) {
    final result = <String, dynamic>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      // ISO8601形式の文字列ならDateTimeに変換
      if (value is String && _isIso8601(value)) {
        result[entry.key] = DateTime.parse(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  bool _isIso8601(String value) {
    try {
      DateTime.parse(value);
      return value.contains('T') || value.contains('-');
    } catch (_) {
      return false;
    }
  }

  String _buildPath(
    String tableName,
    String userId,
    String recordId,
    String? parentId,
  ) {
    switch (tableName) {
      case 'folders':
        return FirestorePath.folder(userId, recordId);
      case 'words':
        if (parentId == null) {
          throw Exception('parentId is required for words');
        }
        return FirestorePath.word(userId, parentId, recordId);
      case 'test_results':
        return FirestorePath.testResult(userId, recordId);
      case 'settings':
        return FirestorePath.settings(userId);
      default:
        throw Exception('Unknown table_name: $tableName');
    }
  }
}
```

### タスク5-2：AutoSyncServiceを作成

**対象ファイル**
- `lib/infrastructure/sync/auto_sync_service.dart`

**実装内容**

```dart
import 'dart:async';
import 'package:wordstock/infrastructure/data_sources/network/connectivity_monitor.dart';
import 'sync_service.dart';

class AutoSyncService {
  final ConnectivityMonitor _connectivityMonitor;
  final SyncService _syncService;
  StreamSubscription<bool>? _subscription;

  AutoSyncService({
    required ConnectivityMonitor connectivityMonitor,
    required SyncService syncService,
  })  : _connectivityMonitor = connectivityMonitor,
        _syncService = syncService;

  void start() {
    _subscription?.cancel();
    _subscription = _connectivityMonitor.onStatusChanged().listen((isOnline) {
      if (isOnline) {
        _syncService.syncLocalToRemote();
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

### タスク5-3：アプリ起動時にAutoSyncServiceを起動

**対象ファイル**
- `lib/app.dart` または `lib/main.dart`

アプリのルートで`AutoSyncService.start()`を呼び出す。
Providerから取得して起動する。

### フェーズ5の完了条件
- [ ] SyncServiceが実装されている
- [ ] AutoSyncServiceが実装されている
- [ ] アプリ起動時にAutoSyncServiceが起動している
- [ ] 機内モードで単語を作成→機内モード解除→自動でFirestoreに同期されることを確認している
- [ ] sync_queueが空になっていることを確認している

---

## フェーズ6：リモート→ローカル同期(ログイン時)

### 設計方針：UPSERT時の競合チェック

リモート→ローカルのUPSERT時は、単純に`ConflictAlgorithm.replace`で上書きしてはいけない。
ローカル側に未同期の編集が残っている可能性があるため、以下のチェックを行う必要がある。

**UPSERTの判定ロジック**

```
既存レコードをSQLiteから取得
├── 存在しない → INSERT（新規追加）
└── 存在する
    ├── syncStatus == 'pending' → スキップ（オフライン編集中のデータを守る）
    ├── localUpdatedAt > remoteUpdatedAt → スキップ（ローカルが新しい）
    └── それ以外 → UPDATE（リモートで上書き）
```

**なぜこのチェックが必要か**

以下のようなシナリオで問題が起きるため。

```
14:00 ユーザーがオフラインで単語を編集（ローカルのupdatedAt=14:00、syncStatus=pending）
14:05 オンライン復帰前にresumedが発火
14:05 Firestoreから差分取得（Firestoreには13:00の古いデータ）
→ 単純にreplaceするとローカルの14:00の編集が13:00で上書きされる
→ ユーザーのオフライン編集が消える
```

このため、リモート→ローカル同期では必ずupdatedAt比較とsyncStatusチェックを行う。

---

### タスク6-1:SyncServiceにログイン時同期メソッドを追加

**対象ファイル**
- `lib/infrastructure/sync/sync_service.dart`

**実装内容**

```dart
/// ログイン成功時にFirestoreからSQLiteに全データを取得する
Future<void> syncRemoteToLocalOnLogin({
  required FolderLocalDataSource folderLocalDataSource,
  required WordLocalDataSource wordLocalDataSource,
  required TestResultLocalDataSource testResultLocalDataSource,
  required SettingsLocalDataSource settingsLocalDataSource,
  required DatabaseHelper dbHelper,
}) async {
  final userId = _getCurrentUserId();

  // foldersを取得
  final foldersSnapshot = await _firestore
      .collection(FirestorePath.folders(userId))
      .get();

  final db = await dbHelper.database;

  // foldersをUPSERT（競合チェック付き）
  await db.transaction((txn) async {
    for (final folderDoc in foldersSnapshot.docs) {
      await _upsertFolderWithConflictCheck(txn, folderDoc, userId);
    }
  });

  // 各フォルダのwordsを取得してUPSERT
  for (final folderDoc in foldersSnapshot.docs) {
    final wordsSnapshot = await _firestore
        .collection(FirestorePath.words(userId, folderDoc.id))
        .get();

    await db.transaction((txn) async {
      for (final wordDoc in wordsSnapshot.docs) {
        await _upsertWordWithConflictCheck(txn, wordDoc, userId, folderDoc.id);
      }
    });
  }

  // test_results、settings も同様のパターンで実装
  // （各エンティティ用のUPSERTメソッドを用意する）

  // lastSyncedAt を更新
  await _updateLastSyncedAt(dbHelper);
}

/// フォルダのUPSERT（競合チェック付き）
Future<void> _upsertFolderWithConflictCheck(
  Transaction txn,
  DocumentSnapshot folderDoc,
  String userId,
) async {
  final remoteData = folderDoc.data() as Map<String, dynamic>;
  final remoteUpdatedAt = (remoteData['updatedAt'] as Timestamp).toDate();

  // ローカルの既存レコードをチェック
  final localRows = await txn.query(
    FolderTable.tableName,
    where: 'id = ?',
    whereArgs: [folderDoc.id],
  );

  if (localRows.isNotEmpty) {
    final localRow = localRows.first;
    final syncStatus = localRow['syncStatus'] as String;

    // オフライン編集中のデータは絶対に上書きしない
    if (syncStatus == 'pending') {
      return;
    }

    // ローカルの方が新しい場合はスキップ
    final localUpdatedAt = DateTime.parse(localRow['updatedAt'] as String);
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return;
    }
  }

  // ここまで来たら、リモートが新しいかローカルに存在しない → UPSERT実行
  await txn.insert(
    FolderTable.tableName,
    {
      'id': folderDoc.id,
      'name': remoteData['name'] as String,
      'parentFolderId': remoteData['parentFolderId'] as String?,
      'userId': userId,
      'createdAt': (remoteData['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': remoteUpdatedAt.toIso8601String(),
      'syncStatus': 'synced',
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// 単語のUPSERT(競合チェック付き)
Future<void> _upsertWordWithConflictCheck(
  Transaction txn,
  DocumentSnapshot wordDoc,
  String userId,
  String folderId,
) async {
  final remoteData = wordDoc.data() as Map<String, dynamic>;
  final remoteUpdatedAt = (remoteData['updatedAt'] as Timestamp).toDate();

  // ローカルの既存レコードをチェック
  final localRows = await txn.query(
    WordTable.tableName,
    where: 'id = ?',
    whereArgs: [wordDoc.id],
  );

  if (localRows.isNotEmpty) {
    final localRow = localRows.first;
    final syncStatus = localRow['syncStatus'] as String;

    // オフライン編集中のデータは絶対に上書きしない
    if (syncStatus == 'pending') {
      return;
    }

    // ローカルの方が新しい場合はスキップ
    final localUpdatedAt = DateTime.parse(localRow['updatedAt'] as String);
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return;
    }
  }

  // UPSERT実行
  await txn.insert(
    WordTable.tableName,
    {
      'id': wordDoc.id,
      'front': remoteData['front'] as String,
      'back': remoteData['back'] as String,
      'folderId': folderId,
      'userId': userId,
      'createdAt': (remoteData['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': remoteUpdatedAt.toIso8601String(),
      'syncStatus': 'synced',
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// test_results、settings用のUPSERTメソッドも同様のパターンで実装する

Future<void> _updateLastSyncedAt(DatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  await db.insert(
    SyncMetaTable.tableName,
    {
      'key': 'lastSyncedAt',
      'value': DateTime.now().toIso8601String(),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

**重要ポイント**
- syncStatus='pending'のレコードは絶対に上書きしない（オフライン編集中のデータを守る）
- updatedAt比較でローカルの方が新しい場合もスキップ
- 全てのUPSERT処理をトランザクション内で実行する
- 各エンティティごとにUPSERTヘルパーメソッドを用意する

### タスク6-2：ログインフローに同期処理を組み込む

**対象ファイル**
- `lib/application/use_cases/auth/sign_in_with_email_use_case.dart`
- `lib/application/use_cases/auth/sign_in_with_google_use_case.dart`
- `lib/application/use_cases/auth/sign_up_use_case.dart`

**実装内容**

ログイン成功後にSyncService.syncRemoteToLocalOnLoginを呼び出す。

### フェーズ6の完了条件
- [ ] syncRemoteToLocalOnLoginが実装されている
- [ ] 全てのリモート→ローカル処理がトランザクション内で実行されている
- [ ] ログイン成功後に自動でFirestoreからSQLiteに全データがコピーされることを確認している
- [ ] lastSyncedAtがsync_metaに記録されていることを確認している

---

## フェーズ7：リモート→ローカル同期（resumed時）

### タスク7-1：SyncServiceにresumed時同期メソッドを追加

**対象ファイル**
- `lib/infrastructure/sync/sync_service.dart`

**実装内容**

フェーズ6で作成した`_upsertFolderWithConflictCheck`、`_upsertWordWithConflictCheck`などの
競合チェック付きUPSERTメソッドを再利用する。

```dart
static const Duration _syncInterval = Duration(minutes: 5);

Future<void> syncRemoteToLocalOnResumed({
  required DatabaseHelper dbHelper,
  required ConnectivityMonitor connectivityMonitor,
}) async {
  // ネットワークチェック
  if (!await connectivityMonitor.isOnline()) return;

  // インターバルチェック
  final lastSyncedAt = await _getLastSyncedAt(dbHelper);
  if (lastSyncedAt != null) {
    final elapsed = DateTime.now().difference(lastSyncedAt);
    if (elapsed < _syncInterval) return;
  }

  final userId = _getCurrentUserId();
  final lastSyncedAtForQuery = lastSyncedAt ?? DateTime(1970);

  final db = await dbHelper.database;

  // foldersの差分取得
  final foldersSnapshot = await _firestore
      .collection(FirestorePath.folders(userId))
      .where('updatedAt', isGreaterThan: lastSyncedAtForQuery)
      .get();

  // 競合チェック付きでUPSERT（フェーズ6のメソッドを再利用）
  await db.transaction((txn) async {
    for (final folderDoc in foldersSnapshot.docs) {
      await _upsertFolderWithConflictCheck(txn, folderDoc, userId);
    }
  });

  // 各フォルダのwordsを差分取得
  // 注意：foldersSnapshotは差分のみなので、全フォルダをループする場合は
  // 別途全フォルダを取得する必要がある。実装方針：
  // (a) 簡易実装：差分があったフォルダのwordsのみチェック
  // (b) 完全実装：全フォルダをループしてwordsの差分をチェック
  //
  // 今回は(b)を採用する。別端末で既存フォルダ内の単語が更新された場合を考慮。
  final allFoldersSnapshot = await _firestore
      .collection(FirestorePath.folders(userId))
      .get();

  for (final folderDoc in allFoldersSnapshot.docs) {
    final wordsSnapshot = await _firestore
        .collection(FirestorePath.words(userId, folderDoc.id))
        .where('updatedAt', isGreaterThan: lastSyncedAtForQuery)
        .get();

    if (wordsSnapshot.docs.isEmpty) continue;

    await db.transaction((txn) async {
      for (final wordDoc in wordsSnapshot.docs) {
        await _upsertWordWithConflictCheck(txn, wordDoc, userId, folderDoc.id);
      }
    });
  }

  // test_results、settings も同様に差分取得してUPSERT

  // lastSyncedAt を更新
  await _updateLastSyncedAt(dbHelper);
}

Future<DateTime?> _getLastSyncedAt(DatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  final rows = await db.query(
    SyncMetaTable.tableName,
    where: 'key = ?',
    whereArgs: ['lastSyncedAt'],
  );
  if (rows.isEmpty) return null;
  return DateTime.parse(rows.first['value'] as String);
}
```

**重要ポイント**
- フェーズ6の競合チェック付きUPSERTメソッド（`_upsertFolderWithConflictCheck`等）を再利用する
- syncStatus='pending'のレコードは守られる
- ローカルが新しい場合もスキップされる
- wordsの差分取得では、全フォルダをループする必要がある点に注意

### タスク7-2：AppLifecycleStateを監視する仕組みを作成

**対象ファイル**
- `lib/core/app_lifecycle_observer.dart`（新規作成）

**実装内容**

```dart
import 'package:flutter/widgets.dart';
import 'package:wordstock/infrastructure/sync/sync_service.dart';
import 'package:wordstock/infrastructure/data_sources/local/database_helper.dart';
import 'package:wordstock/infrastructure/data_sources/network/connectivity_monitor.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final SyncService _syncService;
  final DatabaseHelper _dbHelper;
  final ConnectivityMonitor _connectivityMonitor;

  AppLifecycleObserver({
    required SyncService syncService,
    required DatabaseHelper dbHelper,
    required ConnectivityMonitor connectivityMonitor,
  })  : _syncService = syncService,
        _dbHelper = dbHelper,
        _connectivityMonitor = connectivityMonitor;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncService.syncRemoteToLocalOnResumed(
        dbHelper: _dbHelper,
        connectivityMonitor: _connectivityMonitor,
      );
    }
  }
}
```

`lib/app.dart`でObserverを登録する。

```dart
WidgetsBinding.instance.addObserver(
  AppLifecycleObserver(
    syncService: ref.read(syncServiceProvider),
    dbHelper: ref.read(databaseHelperProvider),
    connectivityMonitor: ref.read(connectivityMonitorProvider),
  ),
);
```

### タスク7-3：Firestoreのインデックスについて

サブコレクション構成のため、多くの場合は**複合インデックスは不要**。
`collection('users/{userId}/folders').where('updatedAt', isGreaterThan: xxx)` は
単一フィールドのクエリなので自動インデックスで動作する。

**もしクエリ実行時にエラーが出た場合**、エラーメッセージに含まれるリンクをクリックすると
Firebase Consoleで自動的にインデックスが作成される。

### フェーズ7の完了条件
- [ ] syncRemoteToLocalOnResumedが実装されている
- [ ] AppLifecycleObserverが実装されている
- [ ] app.dartでObserverが登録されている
- [ ] 5分未満のresumedはスキップされることを確認している
- [ ] 5分以上経過後のresumedで差分取得が実行されることを確認している

---

## フェーズ8：競合解決とエラーハンドリング

### タスク8-1：Firestoreトランザクションで競合解決

**対象ファイル**
- `lib/infrastructure/sync/sync_service.dart`

**実装内容**

`_processQueueItem`のFirestore書き込み部分をトランザクションで囲む。

```dart
await _firestore.runTransaction((transaction) async {
  final docRef = _firestore.doc(path);
  final docSnapshot = await transaction.get(docRef);

  if (docSnapshot.exists) {
    final remoteData = docSnapshot.data()!;
    final remoteUpdatedAt = (remoteData['updatedAt'] as Timestamp).toDate();
    final localUpdatedAtStr = decoded['updatedAt'] as String;
    final localUpdatedAt = DateTime.parse(localUpdatedAtStr);

    // リモートの方が新しければスキップ
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return;
    }
  }

  // ローカルが新しいか、リモートにドキュメントが存在しない → 書き込み
  transaction.set(docRef, firestoreData);
});
```

### タスク8-2：エラーハンドリングの方針

**基本方針：失敗したら同期を中断する**

運用上、以下の理由により「失敗したらスキップして次へ」の方針は採用しない。
- 権限エラーはほぼ発生しない（ユーザーは自分のデータを操作するため）
- ネットワークエラー以外の予期しないエラーは、クライアント側のバグの可能性が高い
- 失敗時に中断することで、キューの処理順序が完全に保たれる

### 順序保証の仕組み

「失敗したら中断」方針は、エラーハンドリングと同時に**同期順序の依存関係解決**も
実現している。仕組みは以下の通り。

```
① キューはcreated_at順に積まれる（ユーザーの操作順序）
② 同期処理は古い順に1件ずつ処理する
③ 失敗したらそこで止まる
④ 未処理のレコードは順序を保ったままキューに残る
⑤ 次回の同期で残ったキューの先頭から再開する
```

これにより、ユーザーが操作した順番通りに必ずFirestoreに反映される。
フォルダ→単語の依存関係も、created_at順で自然に解決される。

### トレードオフ（許容するデメリット）

本方針には以下のデメリットがある。

**キュー先頭の壊れたレコードが、後続のレコード全てをブロックする**

たとえばキューの先頭のレコードが何らかの理由で永続的に失敗し続けると、
そのレコード以降のキューが永遠に処理されなくなる。

しかし以下の理由から、このデメリットは許容する。
- 通常の運用で壊れたレコードが生まれるケースはほぼない
- もし発生した場合はクライアント側のバグであり、本来修正すべきもの
- 過剰なエラーハンドリングでコードを複雑にするより、シンプルさを優先する

### 追加で行うエラーハンドリング

1. **ネットワーク状態の事前チェック**
   同期開始前にConnectivityMonitorでオンライン確認。オフラインならスキップ。

2. **ログ出力**
   エラー発生時にログに記録して、開発時のデバッグを容易にする。

```dart
Future<void> syncLocalToRemote() async {
  // 同期開始前にネットワークチェック
  if (!await _connectivityMonitor.isOnline()) {
    return;
  }

  final userId = _getCurrentUserId();
  final queueItems = await _syncQueueDataSource.getAll();

  for (final item in queueItems) {
    try {
      await _processQueueItem(item, userId);
      await _syncQueueDataSource.delete(item['id'] as int);
    } catch (e, stack) {
      // ログに記録して中断
      print('Sync failed: $e\n$stack');
      break;
    }
  }
}
```

### フェーズ8の完了条件
- [ ] Firestoreトランザクションでの競合解決が実装されている
- [ ] 各種エラーハンドリングが実装されている
- [ ] 複数端末での動作確認（可能であれば）

---

## 各フェーズ完了後のコミット運用

### ブランチ戦略
- mainブランチから`feature/offline-sync-phase{N}`ブランチを切る
- フェーズ完了時にPRを作成してmainにマージ
- 次のフェーズは新しいブランチで作業

### コミットメッセージ例
```
feat: add updatedAt field to models (phase1)
feat: add firestore path class (phase1)
feat: create sqlite tables with separated design (phase2)
feat: implement local data sources (phase3)
feat: implement offline write with transaction (phase4)
feat: implement local to remote auto sync (phase5)
feat: implement remote to local sync on login (phase6)
feat: implement remote to local sync on resumed (phase7)
feat: implement conflict resolution (phase8)
```

---

## テスト方針

本機能のテストは、CI/CDパイプラインの実働証明を主目的とする。
網羅的なテストカバレッジよりも、以下のシナリオが動作することを重視する。

### 最低限確認すべきシナリオ

1. **オフライン書き込み**
   - 機内モードで単語を登録 → SQLiteに保存される、sync_queueに積まれる

2. **オンライン復帰時の自動同期**
   - 機内モード解除 → 自動でFirestoreに同期される、sync_queueが空になる

3. **ログイン時の全データ取得**
   - アプリ再インストール後にログイン → Firestoreから全データが取得される

4. **resumed時の差分取得**
   - 別端末でデータ変更 → アプリに戻ると差分が反映される
   - 5分以内の再度のresumedはスキップされる

5. **競合解決**
   - ローカルとリモートで同時に変更 → updatedAtが新しい方が採用される

---

## READMEへの追記

実装完了後、READMEに以下のセクションを追記する。

```markdown
## オフライン対応

### 設計思想
WordStockはローカルファースト設計を採用しています。
ユーザーがネットワーク環境外でもアプリを継続利用でき、
オンライン復帰時に自動でFirestoreと同期されます。

### 同期アーキテクチャ
- 書き込み：オンライン時はFirestore + SQLite両方、オフライン時はSQLiteのみ
- 読み取り：常にSQLiteから（UIはオン/オフラインを意識しない）
- 同期：オンライン復帰時に自動でキューからFirestoreに反映

### 技術ポイント
- sync_queueテーブルによる操作のキューイング
- SQLiteトランザクションによるデータ整合性の担保
- connectivity_plusによるネットワーク状態監視
- FirestoreトランザクションによるLast-Write-Wins競合解決
- AppLifecycleStateを活用したresumed時の差分同期（5分インターバル付き）
```

---

## 実装時の注意事項

### してはいけないこと
- フェーズを飛ばして実装する
- 既存のクリーンアーキテクチャを壊す
- UI層に同期ロジックを書く
- SQLiteトランザクション内でFirestore通信を行う
- payloadにsyncStatusやSQLite専用カラムを含める
- データ書き込みとsync_queue登録をトランザクション外で別々に実行する

### 必ずやること
- 各フェーズの完了条件を満たしてから次に進む
- エラーハンドリングを省略しない
- 既存のRiverpod + Freezed + riverpod_generatorパターンに従う
- SQLiteの複数操作はトランザクションで囲む
- DateTime型の変換責任はLocalDataSource層に集約する
- 各フェーズ完了時にコミット＆PR作成
