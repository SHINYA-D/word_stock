import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/folder_providers.dart';
import 'package:word_stock/core/di/flashcard_result_providers.dart';

part 'result_view_model.g.dart';

@riverpod
class ResultViewModel extends _$ResultViewModel {
  late String _userId;

  @override
  Future<List<FlashcardResult>> build() async {
    _userId = ref.watch(currentUserProvider)?.id ?? '';
    final result = await ref.read(getFlashcardResultsUseCaseProvider).call(
          userId: _userId,
        );
    return result.fold((f) => throw f, (v) => v);
  }

  Future<void> refresh({String? folderId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(getFlashcardResultsUseCaseProvider).call(
            userId: _userId,
          );
      return result.fold((f) => throw f, (v) => v);
    });
  }
}

@riverpod
Future<Map<String, String>> folderNames(Ref ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  final result = await ref.read(getFoldersUseCaseProvider).call(userId: userId);
  return result.fold(
    (f) => {},
    (folders) => {for (final f in folders) f.id: f.name},
  );
}
