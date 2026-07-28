import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/application/use_cases/word/create_word_use_case.dart';
import 'package:word_stock/application/use_cases/word/delete_word_use_case.dart';
import 'package:word_stock/application/use_cases/word/get_words_use_case.dart';
import 'package:word_stock/application/use_cases/word/update_word_use_case.dart';
import 'package:word_stock/core/di/repository_providers.dart';

part 'word_providers.g.dart';

@Riverpod(keepAlive: true)
GetWordsUseCase getWordsUseCase(Ref ref) =>
    GetWordsUseCase(ref.watch(wordRepositoryProvider));

@Riverpod(keepAlive: true)
CreateWordUseCase createWordUseCase(Ref ref) =>
    CreateWordUseCase(ref.watch(wordRepositoryProvider));

@Riverpod(keepAlive: true)
UpdateWordUseCase updateWordUseCase(Ref ref) =>
    UpdateWordUseCase(ref.watch(wordRepositoryProvider));

@Riverpod(keepAlive: true)
DeleteWordUseCase deleteWordUseCase(Ref ref) =>
    DeleteWordUseCase(ref.watch(wordRepositoryProvider));
