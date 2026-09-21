import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/tables/settings_table.dart';

void main() {
  const userId = 'user-1';

  late DatabaseHelper dbHelper;
  late SettingsLocalDataSource dataSource;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 他のテストファイルと同時実行された際にDBファイルのロック競合が
    // 発生しないよう、このテストファイル専用の一時ディレクトリを使う。
    final tempDir = await Directory.systemTemp.createTemp(
      'settings_local_data_source_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete(SettingsTable.tableName);
    dataSource = SettingsLocalDataSource(dbHelper);
  });

  group('upsert / findByUserId', () {
    test('新規レコードをupsertした場合、findByUserIdで同じ値が取得できる（DateTimeの往復変換を含む）',
        () async {
      final settings = UserSettings(
        colorTheme: 'blue',
        darkMode: true,
        updatedAt: DateTime(2024, 3, 1, 12, 30),
      );

      await dataSource.upsert(settings, userId: userId);

      final result = await dataSource.findByUserId(userId);
      expect(result, isNotNull);
      expect(result!.colorTheme, 'blue');
      expect(result.darkMode, isTrue);
      expect(result.updatedAt, DateTime(2024, 3, 1, 12, 30));
    });

    test('darkModeがfalseの場合、0として保存され取得時にfalseへ変換される', () async {
      final settings = UserSettings(
        colorTheme: 'indigo',
        darkMode: false,
        updatedAt: DateTime(2024, 1, 1),
      );

      await dataSource.upsert(settings, userId: userId);

      final result = await dataSource.findByUserId(userId);
      expect(result!.darkMode, isFalse);
    });

    test('syncStatusを指定した場合、その値がsyncStatusカラムに保存される', () async {
      final settings = UserSettings(
        colorTheme: 'indigo',
        darkMode: false,
        updatedAt: DateTime(2024, 1, 1),
      );

      await dataSource.upsert(settings, userId: userId, syncStatus: 'pending');

      final db = await dbHelper.database;
      final rows = await db.query(
        SettingsTable.tableName,
        where: 'userId = ?',
        whereArgs: [userId],
      );
      expect(rows.single['syncStatus'], 'pending');
    });

    test('別のuserIdのレコードが存在する場合、指定したuserIdのレコードのみ取得できる', () async {
      await dataSource.upsert(
        UserSettings(
          colorTheme: 'blue',
          darkMode: true,
          updatedAt: DateTime(2024, 1, 1),
        ),
        userId: userId,
      );
      await dataSource.upsert(
        UserSettings(
          colorTheme: 'red',
          darkMode: false,
          updatedAt: DateTime(2024, 1, 2),
        ),
        userId: 'other-user',
      );

      final result = await dataSource.findByUserId(userId);
      expect(result!.colorTheme, 'blue');
    });

    test('存在しないuserIdを指定した場合、nullが返る', () async {
      final result = await dataSource.findByUserId('not-exist');
      expect(result, isNull);
    });

    test('同じuserIdで2回upsertした場合、レコードが上書きされ最新の値のみ取得できる', () async {
      await dataSource.upsert(
        UserSettings(
          colorTheme: 'blue',
          darkMode: true,
          updatedAt: DateTime(2024, 1, 1),
        ),
        userId: userId,
      );
      await dataSource.upsert(
        UserSettings(
          colorTheme: 'green',
          darkMode: false,
          updatedAt: DateTime(2024, 2, 1),
        ),
        userId: userId,
      );

      final db = await dbHelper.database;
      final rows = await db.query(
        SettingsTable.tableName,
        where: 'userId = ?',
        whereArgs: [userId],
      );
      expect(rows.length, 1);

      final result = await dataSource.findByUserId(userId);
      expect(result!.colorTheme, 'green');
      expect(result.darkMode, isFalse);
      expect(result.updatedAt, DateTime(2024, 2, 1));
    });

    test('updatedAtがnullの場合、現在時刻が採用され取得時にnullではない値が返る', () async {
      final before = DateTime.now();
      const settings = UserSettings(
        colorTheme: 'indigo',
        darkMode: false,
        updatedAt: null,
      );

      await dataSource.upsert(settings, userId: userId);
      final after = DateTime.now();

      final result = await dataSource.findByUserId(userId);
      expect(result!.updatedAt, isNotNull);
      expect(
        result.updatedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        result.updatedAt!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
