import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/sync_queue_table.dart';
import 'package:word_stock/infrastructure/repositories/settings_repository_impl.dart';

import '../../helpers/fake_infrastructure.dart';

/// ローカルの読み取りで例外を投げる（STG-R05）。
class ThrowingFindByUserIdSettingsLocalDataSource
    extends SettingsLocalDataSource {
  ThrowingFindByUserIdSettingsLocalDataSource(super.dbHelper);

  @override
  Future<UserSettings?> findByUserId(String userId) {
    throw Exception('read failed');
  }
}

/// ローカルへの保存で例外を投げる（STG-U04）。
class ThrowingSaveSettingsLocalDataSource extends SettingsLocalDataSource {
  ThrowingSaveSettingsLocalDataSource(super.dbHelper);

  @override
  Future<void> save(
    DatabaseExecutor db,
    UserSettings settings, {
    required String userId,
    String syncStatus = 'synced',
  }) {
    throw Exception('save failed');
  }
}

/// キューへの登録で例外を投げる（STG-U05）。
class ThrowingEnqueueSyncQueueDataSource extends SyncQueueDataSource {
  ThrowingEnqueueSyncQueueDataSource(super.dbHelper);

  @override
  Future<void> enqueueInTransaction(
    DatabaseExecutor txn, {
    required String operation,
    required String tableName,
    required String recordId,
    required String userId,
    String? parentId,
  }) {
    throw Exception('enqueue failed');
  }
}

void main() {
  const userId = 'user-1';
  const otherUserId = 'user-2';

  late DatabaseHelper dbHelper;
  late SettingsLocalDataSource settingsLocal;
  late SyncQueueDataSource syncQueue;
  late int onLocalChangedCallCount;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は 'wordstock.db' という固定のファイル名を使うため、
    // 他のテストファイルと同時実行された際に同一パスを取り合ってロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'settings_repository_impl_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    // テスト間でDBの中身が混ざらないよう、毎回まっさらなDBファイルを使う。
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(SettingsTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    settingsLocal = SettingsLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    onLocalChangedCallCount = 0;
  });

  SettingsRepositoryImpl buildRepository({
    SettingsLocalDataSource? localDataSource,
    SyncQueueDataSource? syncQueueDataSource,
  }) {
    return SettingsRepositoryImpl(
      localDataSource: localDataSource ?? settingsLocal,
      syncQueueDataSource: syncQueueDataSource ?? syncQueue,
      dbHelper: dbHelper,
      onLocalChanged: () => onLocalChangedCallCount++,
    );
  }

  Future<void> insertSettings(
    String forUserId, {
    String colorTheme = 'indigo',
    bool darkMode = false,
    required DateTime updatedAt,
  }) =>
      settingsLocal.upsert(
        UserSettings(
          colorTheme: colorTheme,
          darkMode: darkMode,
          updatedAt: updatedAt,
        ),
        userId: forUserId,
      );

  Future<Map<String, dynamic>?> settingsRow(String forUserId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      SettingsTable.tableName,
      where: 'userId = ?',
      whereArgs: [forUserId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  group('getSettings', () {
    test('ローカルにUの設定がない場合、戻り値がRightでカラーテーマ「indigo」・ダークモードfalse [STG-R01]',
        () async {
      final repository = buildRepository();

      final result = await repository.getSettings(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (settings) {
          expect(settings.colorTheme, 'indigo');
          expect(settings.darkMode, isFalse);
        },
      );
    });

    test(
        'ローカルにUの設定（カラーテーマ「teal」・ダークモードtrue）がある場合、'
        '戻り値がRightでカラーテーマ「teal」・ダークモードtrue [STG-R02]', () async {
      final repository = buildRepository();
      await insertSettings(
        userId,
        colorTheme: 'teal',
        darkMode: true,
        updatedAt: DateTime(2024, 1, 1),
      );

      final result = await repository.getSettings(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (settings) {
          expect(settings.colorTheme, 'teal');
          expect(settings.darkMode, isTrue);
        },
      );
    });

    test(
        'ローカルにUの設定がなく、ユーザーVの設定（カラーテーマ「pink」）がある場合、'
        '戻り値がRightでカラーテーマ「indigo」 [STG-R03]', () async {
      final repository = buildRepository();
      await insertSettings(
        otherUserId,
        colorTheme: 'pink',
        updatedAt: DateTime(2024, 1, 1),
      );

      final result = await repository.getSettings(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (settings) => expect(settings.colorTheme, 'indigo'),
      );
    });

    test('オフラインで、ローカルにUの設定（カラーテーマ「teal」）がある場合、戻り値がRightでカラーテーマ「teal」 [STG-R04]',
        () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline(); // オフライン状態を明示するだけで、結果には影響しない
      await insertSettings(
        userId,
        colorTheme: 'teal',
        updatedAt: DateTime(2024, 1, 1),
      );

      final result = await repository.getSettings(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (settings) => expect(settings.colorTheme, 'teal'),
      );
    });

    test('ローカルの読み取りが失敗した場合、戻り値がLeft(UnknownFailure) [STG-R05]', () async {
      final repository = buildRepository(
        localDataSource: ThrowingFindByUserIdSettingsLocalDataSource(dbHelper),
      );

      final result = await repository.getSettings(userId: userId);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('updateSettings', () {
    test(
        'オンラインで、Uの設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」・'
        'ダークモードtrueに変更した場合、戻り値がRight(unit)。その後のgetSettingsがカラーテーマ「teal」・'
        'ダークモードtrueで、updatedAtが変更前のupdatedAtより後。キューが1件増える [STG-U01]',
        () async {
      final repository = buildRepository();
      final beforeUpdatedAt = DateTime(2023, 1, 1);
      await insertSettings(userId, updatedAt: beforeUpdatedAt);

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal', darkMode: true),
      );

      expect(result.isRight(), isTrue);
      final after = await repository.getSettings(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (settings) {
          expect(settings.colorTheme, 'teal');
          expect(settings.darkMode, isTrue);
          expect(settings.updatedAt!.isAfter(beforeUpdatedAt), isTrue);
        },
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'オフラインで、Uの設定（カラーテーマ「indigo」）がある状態で、カラーテーマ「teal」に'
        '変更した場合、戻り値がRight(unit)。その後のgetSettingsのカラーテーマが「teal」。'
        'キューが1件増える [STG-U02]', () async {
      final repository = buildRepository();
      final fakeConnectivity = FakeConnectivityMonitor(online: false);
      await fakeConnectivity.isOnline();
      await insertSettings(userId, updatedAt: DateTime(2023, 1, 1));

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal'),
      );

      expect(result.isRight(), isTrue);
      final after = await repository.getSettings(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (settings) => expect(settings.colorTheme, 'teal'),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'ローカルにUの設定がない状態で、カラーテーマ「teal」に変更した場合、戻り値がRight(unit)。'
        'その後のgetSettingsのカラーテーマが「teal」で、updatedAtがnullでない。キューが1件増える [STG-U03]',
        () async {
      final repository = buildRepository();

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal'),
      );

      expect(result.isRight(), isTrue);
      final after = await repository.getSettings(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (settings) {
          expect(settings.colorTheme, 'teal');
          expect(settings.updatedAt, isNotNull);
        },
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test(
        'Uの設定（カラーテーマ「indigo」）の変更で、ローカルへの保存が失敗した場合、'
        '戻り値がLeft(UnknownFailure)。その後のgetSettingsのカラーテーマが「indigo」のまま。'
        'キューの件数が変わらない [STG-U04]', () async {
      await insertSettings(userId, updatedAt: DateTime(2023, 1, 1));
      final repository = buildRepository(
        localDataSource: ThrowingSaveSettingsLocalDataSource(dbHelper),
      );

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal'),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await settingsLocal.findByUserId(userId);
      expect(after!.colorTheme, 'indigo');
      expect(await syncQueue.countByUser(userId), 0);
    });

    test(
        'Uの設定（カラーテーマ「indigo」）の変更で、保存は成功しキューへの登録が失敗した場合、'
        '戻り値がLeft(UnknownFailure)。その後のgetSettingsのカラーテーマが「indigo」のまま [STG-U05]',
        () async {
      await insertSettings(userId, updatedAt: DateTime(2023, 1, 1));
      final repository = buildRepository(
        syncQueueDataSource: ThrowingEnqueueSyncQueueDataSource(dbHelper),
      );

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal'),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
      final after = await repository.getSettings(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (settings) => expect(settings.colorTheme, 'indigo'),
      );
    });

    test(
        'Uの設定（カラーテーマ「indigo」・ダークモードfalse）がある状態で、同じ値で変更した場合、'
        '戻り値がRight(unit)。updatedAtが変更前のupdatedAtより後。キューが1件増える [STG-U06]',
        () async {
      final repository = buildRepository();
      final beforeUpdatedAt = DateTime(2023, 1, 1);
      await insertSettings(userId, updatedAt: beforeUpdatedAt);

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'indigo', darkMode: false),
      );

      expect(result.isRight(), isTrue);
      final after = await repository.getSettings(userId: userId);
      after.match(
        (_) => fail('Right が返るはず'),
        (settings) =>
            expect(settings.updatedAt!.isAfter(beforeUpdatedAt), isTrue),
      );
      expect(await syncQueue.countByUser(userId), 1);
    });

    test('変更した直後（送信前）は、ローカルのUの設定のsyncStatusがpending [STG-U07]', () async {
      final repository = buildRepository();
      await insertSettings(userId, updatedAt: DateTime(2023, 1, 1));

      await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal'),
      );

      final row = await settingsRow(userId);
      expect(row, isNotNull);
      expect(row!['syncStatus'], 'pending');
    });

    test(
        'Uの設定とユーザーVの設定（カラーテーマ「pink」）がある状態で、Uの設定をカラーテーマ「teal」に'
        '変更した場合、Vの設定のカラーテーマが「pink」のまま [STG-U08]', () async {
      final repository = buildRepository();
      await insertSettings(userId, updatedAt: DateTime(2023, 1, 1));
      await insertSettings(
        otherUserId,
        colorTheme: 'pink',
        updatedAt: DateTime(2023, 1, 1),
      );

      await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'teal'),
      );

      final row = await settingsRow(otherUserId);
      expect(row!['colorTheme'], 'pink');
    });
  });
}
