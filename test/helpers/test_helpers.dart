import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_auth_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_folder_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_settings_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_flashcard_result_repository.dart';
import 'package:word_stock/infrastructure/repositories/mock/mock_word_repository.dart';

/// テスト用モックユーザー（MockFolderRepository / MockWordRepository のサンプルデータと同じ ID）
const testUser = AppUser(id: 'mock-user-id', email: 'dev@example.com');

/// テスト用フォルダ一覧
final testFolders = [
  Folder(id: 'folder-1', name: '英単語', createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1)),
  Folder(id: 'folder-2', name: 'TOEIC 頻出', createdAt: DateTime(2024, 1, 2), updatedAt: DateTime(2024, 1, 2)),
];

/// テスト用単語一覧
final testWords = [
  Word(id: 'word-1', front: 'apple', back: 'りんご', createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1)),
  Word(id: 'word-2', front: 'banana', back: 'バナナ', createdAt: DateTime(2024, 1, 2), updatedAt: DateTime(2024, 1, 2)),
  Word(id: 'word-3', front: 'cherry', back: 'さくらんぼ', createdAt: DateTime(2024, 1, 3), updatedAt: DateTime(2024, 1, 3)),
];

/// モックリポジトリとテストユーザーをすべて注入した ProviderScope + MaterialApp を返すヘルパー。
/// Firebase に依存しないため Widget テストで安全に利用できる。
Widget buildWithMockRepositories({
  required Widget child,
  List<Override> extra = const [],
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      folderRepositoryProvider.overrideWithValue(MockFolderRepository()),
      wordRepositoryProvider.overrideWithValue(MockWordRepository()),
      settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
      flashcardResultRepositoryProvider.overrideWithValue(MockFlashcardResultRepository()),
      currentUserProvider.overrideWithValue(testUser),
      ...extra,
    ],
    child: MaterialApp(home: child),
  );
}
