import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late SettingsLocalDataSource settingsLocal;
  late SyncQueueDataSource syncQueue;
  late FakeFirestoreDataSource fakeRemote;
  late FakeConnectivityMonitor fakeConnectivity;
  late SettingsRepositoryImpl repository;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // DatabaseHelper は固定のファイル名を使うため、他のテストファイルと同時実行された際に
    // 同一パスを取り合ってロック競合が発生しないよう、専用の一時ディレクトリに切り替える。
    final tempDir = await Directory.systemTemp.createTemp(
      'settings_repository_impl_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(SettingsTable.tableName);
    await db.delete(SyncQueueTable.tableName);

    settingsLocal = SettingsLocalDataSource(dbHelper);
    syncQueue = SyncQueueDataSource(dbHelper);
    fakeRemote = FakeFirestoreDataSource();
    fakeConnectivity = FakeConnectivityMonitor(online: true);

    repository = SettingsRepositoryImpl(
      localDataSource: settingsLocal,
      remoteDataSource: fakeRemote,
      syncQueueDataSource: syncQueue,
      dbHelper: dbHelper,
      connectivityMonitor: fakeConnectivity,
    );
  });

  Future<List<Map<String, dynamic>>> queueRowsFor(String recordId) async {
    final db = await dbHelper.database;
    return db.query(
      SyncQueueTable.tableName,
      where: 'table_name = ? AND record_id = ? AND operation = ?',
      whereArgs: [SettingsTable.tableName, recordId, 'update'],
    );
  }

  group('getSettings', () {
    test('ローカルに設定が保存されている場合、その設定が返る', () async {
      await settingsLocal.upsert(
        const UserSettings(colorTheme: 'red', darkMode: true),
        userId: userId,
      );

      final result = await repository.getSettings(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (settings) {
          expect(settings.colorTheme, 'red');
          expect(settings.darkMode, isTrue);
        },
      );
    });

    test('ローカルに設定が存在しない場合、デフォルトのUserSettingsが返る', () async {
      final result = await repository.getSettings(userId: userId);

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (settings) => expect(settings, const UserSettings()),
      );
    });

    test('ローカルデータソースが例外を投げた場合、Failure.unknownが返る', () async {
      // findByUserId 内部で例外を発生させるため、テーブル自体を削除して例外を誘発する。
      final db = await dbHelper.database;
      await db.execute('DROP TABLE ${SettingsTable.tableName}');

      final result = await repository.getSettings(userId: userId);

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );

      // 後続のテストに影響しないようテーブルを復元する。
      await SettingsTable.onCreate(db);
    });
  });

  group('updateSettings - オンライン時', () {
    test('設定を更新した場合、ローカル・リモート両方にsynced状態で保存される', () async {
      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'blue', darkMode: true),
      );

      expect(result.isRight(), isTrue);

      final saved = await settingsLocal.findByUserId(userId);
      expect(saved?.colorTheme, 'blue');
      expect(saved?.darkMode, isTrue);

      expect(fakeRemote.writtenSettings, hasLength(1));
      expect(fakeRemote.writtenSettings.single.userId, userId);
      expect(fakeRemote.writtenSettings.single.settings.colorTheme, 'blue');

      // sync_queue には登録されない。
      expect(await queueRowsFor(userId), isEmpty);
    });

    test('updatedAtが指定されていない場合でも、現在時刻が補完されて保存される', () async {
      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(),
      );

      expect(result.isRight(), isTrue);
      final saved = await settingsLocal.findByUserId(userId);
      expect(saved?.updatedAt, isNotNull);
    });

    test('リモート書き込みでFirebaseException(unavailable)が発生した場合、Failure.networkが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
      );

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'green'),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });

    test(
        'リモート書き込みでFirebaseException(network-request-failed)が発生した場合、'
        'Failure.networkが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'network-request-failed',
      );

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'green'),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('リモート書き込みで未知のFirebaseExceptionが発生した場合、Failure.unknownが返る', () async {
      fakeRemote.exceptionToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: '権限がありません',
      );

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'green'),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) {
          expect(failure, isA<UnknownFailure>());
          expect((failure as UnknownFailure).message, '権限がありません');
        },
        (_) => fail('Left が返るはず'),
      );
    });

    test('リモート書き込みで一般的な例外が発生した場合、Failure.unknownが返る', () async {
      fakeRemote.exceptionToThrow = Exception('boom');

      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'green'),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('updateSettings - オフライン時', () {
    setUp(() {
      fakeConnectivity.setOnline(false);
    });

    test('設定を更新した場合、ローカルにpending状態で保存されsync_queueにupdate登録される', () async {
      final result = await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'purple', darkMode: true),
      );

      expect(result.isRight(), isTrue);

      final saved = await settingsLocal.findByUserId(userId);
      expect(saved?.colorTheme, 'purple');
      expect(saved?.darkMode, isTrue);

      final db = await dbHelper.database;
      final rows = await db.query(
        SettingsTable.tableName,
        where: 'userId = ?',
        whereArgs: [userId],
      );
      expect(rows.single['syncStatus'], 'pending');

      expect(await queueRowsFor(userId), hasLength(1));

      // オフラインなのでリモートへの書き込みは行われない。
      expect(fakeRemote.writtenSettings, isEmpty);
    });

    test('同一ユーザーで複数回更新した場合、ローカルの設定行は1件に置き換わる', () async {
      await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'purple'),
      );
      await repository.updateSettings(
        userId: userId,
        settings: const UserSettings(colorTheme: 'yellow'),
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        SettingsTable.tableName,
        where: 'userId = ?',
        whereArgs: [userId],
      );
      expect(rows, hasLength(1));
      expect(rows.single['colorTheme'], 'yellow');
    });
  });
}
