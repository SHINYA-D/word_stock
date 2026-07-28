import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/folder_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/settings_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/flashcard_result_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/local/word_local_data_source.dart';
import 'package:word_stock/infrastructure/data_sources/network/connectivity_monitor.dart';

part 'local_data_source_providers.g.dart';

@Riverpod(keepAlive: true)
DatabaseHelper databaseHelper(Ref ref) => DatabaseHelper();

@Riverpod(keepAlive: true)
ConnectivityMonitor connectivityMonitor(Ref ref) => ConnectivityMonitor();

@Riverpod(keepAlive: true)
SyncQueueDataSource syncQueueDataSource(Ref ref) =>
    SyncQueueDataSource(ref.watch(databaseHelperProvider));

@Riverpod(keepAlive: true)
FolderLocalDataSource folderLocalDataSource(Ref ref) =>
    FolderLocalDataSource(ref.watch(databaseHelperProvider));

@Riverpod(keepAlive: true)
WordLocalDataSource wordLocalDataSource(Ref ref) =>
    WordLocalDataSource(ref.watch(databaseHelperProvider));

@Riverpod(keepAlive: true)
FlashcardResultLocalDataSource flashcardResultLocalDataSource(Ref ref) =>
    FlashcardResultLocalDataSource(ref.watch(databaseHelperProvider));

@Riverpod(keepAlive: true)
SettingsLocalDataSource settingsLocalDataSource(Ref ref) =>
    SettingsLocalDataSource(ref.watch(databaseHelperProvider));
