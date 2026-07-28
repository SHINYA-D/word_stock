import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/core/di/auth_providers.dart';
import 'package:word_stock/core/di/folder_providers.dart';
import 'package:word_stock/presentation/home/home_state.dart';

part 'home_view_model.g.dart';

@riverpod
class HomeViewModel extends _$HomeViewModel {
  late String _userId;
  @override
  HomeState build() {
    Future.microtask(() => _initState());
    return HomeState.loading();
  }

  Future<void> _initState() async {
    _userId = ref.watch(currentUserProvider)?.id ?? '';
    final result = await ref.read(getFoldersUseCaseProvider).call(
          userId: _userId,
        );
    result.fold(
      (failure) {
        state = state.copyWith(
          folders: AsyncValue.error(failure, StackTrace.current),
        );
      },
      (folders) {
        state = state.copyWith(
          folders: AsyncValue.data(folders),
          
        );
      },
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(folders: const AsyncLoading());
    state = state.copyWith(
      folders: await AsyncValue.guard(
        () async {
          final result = await ref.read(getFoldersUseCaseProvider).call(
                userId: _userId,
              );
          return result.fold((failure) => throw failure, (folder) => folder);
        },
      ),
    );
  }

  Future<void> createFolder({required String name}) async {
    final result = await ref.read(createFolderUseCaseProvider).call(
          userId: _userId,
          name: name,
          parentFolderId: null,
        );
    result.fold(
      (failure) => state = state.copyWith(
        folders: AsyncValue.error(failure, StackTrace.current),
      ),
      (folder) {
        final current = state.folders.value ?? [];
        state = state.copyWith(
          folders: AsyncValue.data([...current, folder]),
        );
      },
    );
  }

  Future<void> updateFolder({
    required String folderId,
    required String name,
  }) async {
    final result = await ref.read(updateFolderUseCaseProvider).call(
          userId: _userId,
          folderId: folderId,
          name: name,
        );
    result.fold(
      (failure) => state = state.copyWith(
        folders: AsyncValue.error(failure, StackTrace.current),
      ),
      (updated) {
        final current = state.folders.value ?? [];
        state = state.copyWith(
          folders: AsyncValue.data(
            current.map((f) => f.id == folderId ? updated : f).toList(),
          ),
        );
      },
    );
  }

  Future<void> deleteFolder({required String folderId}) async {
    final result = await ref.read(deleteFolderUseCaseProvider).call(
          userId: _userId,
          folderId: folderId,
        );
    result.fold(
      (failure) => state = state.copyWith(
        folders: AsyncValue.error(failure, StackTrace.current),
      ),
      (_) {
        refresh();
      },
    );
  }
}
