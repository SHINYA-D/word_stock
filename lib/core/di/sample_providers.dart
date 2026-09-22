import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/application/use_cases/sample/create_sample_use_case.dart';
import 'package:word_stock/application/use_cases/sample/delete_sample_use_case.dart';
import 'package:word_stock/application/use_cases/sample/get_samples_use_case.dart';
import 'package:word_stock/application/use_cases/sample/update_sample_use_case.dart';
import 'package:word_stock/core/di/repository_providers.dart';

part 'sample_providers.g.dart';

@Riverpod(keepAlive: true)
GetSamplesUseCase getSamplesUseCase(Ref ref) =>
    GetSamplesUseCase(ref.watch(sampleRepositoryProvider));

@Riverpod(keepAlive: true)
CreateSampleUseCase createSampleUseCase(Ref ref) =>
    CreateSampleUseCase(ref.watch(sampleRepositoryProvider));

@Riverpod(keepAlive: true)
UpdateSampleUseCase updateSampleUseCase(Ref ref) =>
    UpdateSampleUseCase(ref.watch(sampleRepositoryProvider));

@Riverpod(keepAlive: true)
DeleteSampleUseCase deleteSampleUseCase(Ref ref) =>
    DeleteSampleUseCase(ref.watch(sampleRepositoryProvider));
