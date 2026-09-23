import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/di/firebase_providers.dart';
import 'package:word_stock/core/di/local_data_source_providers.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';
import 'package:word_stock/domain/repositories/folder_repository.dart';
import 'package:word_stock/domain/repositories/sample_repository.dart';
import 'package:word_stock/domain/repositories/settings_repository.dart';
import 'package:word_stock/domain/repositories/flashcard_result_repository.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';
import 'package:word_stock/infrastructure/repositories/auth_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/folder_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_auth_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_folder_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_sample_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_settings_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_flashcard_result_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_word_repository.dart';
import 'package:word_stock/infrastructure/repositories/settings_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/flashcard_result_repository_impl.dart';
import 'package:word_stock/infrastructure/repositories/word_repository_impl.dart';

part 'repository_providers.g.dart';

// ---------------------------------------------------------------
// モード切り替えフラグ
// ---------------------------------------------------------------
const kUseMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  if (kUseMocks) return MockAuthRepository();
  return AuthRepositoryImpl(ref.watch(firebaseAuthDataSourceProvider));
}

@Riverpod(keepAlive: true)
FolderRepository folderRepository(Ref ref) {
  if (kUseMocks) return MockFolderRepository();
  return FolderRepositoryImpl(
    localDataSource: ref.watch(folderLocalDataSourceProvider),
    wordLocalDataSource: ref.watch(wordLocalDataSourceProvider),
    flashcardResultLocalDataSource: ref.watch(flashcardResultLocalDataSourceProvider),
    remoteDataSource: ref.watch(firestoreDataSourceProvider),
    syncQueueDataSource: ref.watch(syncQueueDataSourceProvider),
    dbHelper: ref.watch(databaseHelperProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
  );
}

@Riverpod(keepAlive: true)
WordRepository wordRepository(Ref ref) {
  if (kUseMocks) return MockWordRepository();
  return WordRepositoryImpl(
    localDataSource: ref.watch(wordLocalDataSourceProvider),
    remoteDataSource: ref.watch(firestoreDataSourceProvider),
    syncQueueDataSource: ref.watch(syncQueueDataSourceProvider),
    dbHelper: ref.watch(databaseHelperProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
  );
}

@Riverpod(keepAlive: true)
FlashcardResultRepository flashcardResultRepository(Ref ref) {
  if (kUseMocks) return MockFlashcardResultRepository();
  return FlashcardResultRepositoryImpl(
    localDataSource: ref.watch(flashcardResultLocalDataSourceProvider),
    remoteDataSource: ref.watch(firestoreDataSourceProvider),
    syncQueueDataSource: ref.watch(syncQueueDataSourceProvider),
    dbHelper: ref.watch(databaseHelperProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
  );
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  if (kUseMocks) return MockSettingsRepository();
  return SettingsRepositoryImpl(
    localDataSource: ref.watch(settingsLocalDataSourceProvider),
    remoteDataSource: ref.watch(firestoreDataSourceProvider),
    syncQueueDataSource: ref.watch(syncQueueDataSourceProvider),
    dbHelper: ref.watch(databaseHelperProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
  );
}

// テストパイプライン検証用。本実装を持たないため常に Mock を返す
@Riverpod(keepAlive: true)
SampleRepository sampleRepository(Ref ref) => MockSampleRepository();
