import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/application/use_cases/test_result/get_test_results_use_case.dart';
import 'package:word_stock/application/use_cases/test_result/save_test_result_use_case.dart';
import 'package:word_stock/core/di/repository_providers.dart';

part 'test_result_providers.g.dart';

@Riverpod(keepAlive: true)
GetTestResultsUseCase getTestResultsUseCase(Ref ref) =>
    GetTestResultsUseCase(ref.watch(testResultRepositoryProvider));

@Riverpod(keepAlive: true)
SaveTestResultUseCase saveTestResultUseCase(Ref ref) =>
    SaveTestResultUseCase(ref.watch(testResultRepositoryProvider));
