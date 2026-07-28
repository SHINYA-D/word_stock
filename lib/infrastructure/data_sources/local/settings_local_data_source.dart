import 'package:sqflite/sqflite.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'database_helper.dart';
import 'tables/settings_table.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Map<String, dynamic> _toRow(
    UserSettings settings, {
    required String userId,
    String syncStatus = 'synced',
  }) {
    return {
      'userId': userId,
      'colorTheme': settings.colorTheme,
      'darkMode': settings.darkMode ? 1 : 0,
      'updatedAt': (settings.updatedAt ?? DateTime.now()).toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  UserSettings _toSettings(Map<String, dynamic> row) {
    return UserSettings(
      colorTheme: row['colorTheme'] as String,
      darkMode: (row['darkMode'] as int) == 1,
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  Future<void> upsert(
    UserSettings settings, {
    required String userId,
    String syncStatus = 'synced',
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      SettingsTable.tableName,
      _toRow(settings, userId: userId, syncStatus: syncStatus),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserSettings?> findByUserId(String userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      SettingsTable.tableName,
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _toSettings(rows.first);
  }
}
