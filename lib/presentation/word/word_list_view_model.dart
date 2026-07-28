import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/core/di/word_providers.dart';

part 'word_list_view_model.g.dart';

@riverpod
class WordListViewModel extends _$WordListViewModel {
  late String _userId;
  late String _folderId;

  @override
  Future<List<Word>> build(String folderId) async {
    _userId = ref.watch(currentUserProvider)?.id ?? '';
    _folderId = folderId;
    final result = await ref.read(getWordsUseCaseProvider).call(
          userId: _userId,
          folderId: folderId,
        );
    return result.fold((f) => throw f, (v) => v);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(getWordsUseCaseProvider).call(
            userId: _userId,
            folderId: _folderId,
          );
      return result.fold((f) => throw f, (v) => v);
    });
  }

  Future<void> createWord({
    required String front,
    required String back,
  }) async {
    final result = await ref.read(createWordUseCaseProvider).call(
          userId: _userId,
          folderId: _folderId,
          front: front,
          back: back,
        );
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (word) {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data([...current, word]);
      },
    );
  }

  Future<void> updateWord({
    required String wordId,
    required String front,
    required String back,
  }) async {
    final result = await ref.read(updateWordUseCaseProvider).call(
          userId: _userId,
          folderId: _folderId,
          wordId: wordId,
          front: front,
          back: back,
        );
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (updated) {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data(
          current.map((w) => w.id == wordId ? updated : w).toList(),
        );
      },
    );
  }

  Future<void> deleteWord({required String wordId}) async {
    final result = await ref.read(deleteWordUseCaseProvider).call(
          userId: _userId,
          folderId: _folderId,
          wordId: wordId,
        );
    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (_) {
        final current = state.valueOrNull ?? [];
        state = AsyncValue.data(current.where((w) => w.id != wordId).toList());
      },
    );
  }
}
