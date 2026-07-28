import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/application/use_cases/folder/create_folder_use_case.dart';
import 'package:word_stock/application/use_cases/folder/delete_folder_use_case.dart';
import 'package:word_stock/application/use_cases/folder/get_folders_use_case.dart';
import 'package:word_stock/application/use_cases/folder/update_folder_use_case.dart';
import 'package:word_stock/core/di/repository_providers.dart';

part 'folder_providers.g.dart';

@Riverpod(keepAlive: true)
GetFoldersUseCase getFoldersUseCase(Ref ref) =>
    GetFoldersUseCase(ref.watch(folderRepositoryProvider));

@Riverpod(keepAlive: true)
CreateFolderUseCase createFolderUseCase(Ref ref) =>
    CreateFolderUseCase(ref.watch(folderRepositoryProvider));

@Riverpod(keepAlive: true)
UpdateFolderUseCase updateFolderUseCase(Ref ref) =>
    UpdateFolderUseCase(ref.watch(folderRepositoryProvider));

@Riverpod(keepAlive: true)
DeleteFolderUseCase deleteFolderUseCase(Ref ref) =>
    DeleteFolderUseCase(ref.watch(folderRepositoryProvider));
