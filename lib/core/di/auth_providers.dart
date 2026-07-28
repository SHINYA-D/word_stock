import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:word_stock/application/use_cases/auth/reset_password_use_case.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_email_use_case.dart';
import 'package:word_stock/application/use_cases/auth/sign_in_with_google_use_case.dart';
import 'package:word_stock/application/use_cases/auth/sign_out_use_case.dart';
import 'package:word_stock/application/use_cases/auth/sign_up_use_case.dart';
import 'package:word_stock/core/di/repository_providers.dart';
import 'package:word_stock/core/di/sync_providers.dart';
import 'package:word_stock/domain/entities/app_user.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges;

@Riverpod(keepAlive: true)
AppUser? currentUser(Ref ref) => ref.watch(authStateProvider).valueOrNull;

@Riverpod(keepAlive: true)
SignInWithEmailUseCase signInWithEmailUseCase(Ref ref) =>
    SignInWithEmailUseCase(
      ref.watch(authRepositoryProvider),
      ref.watch(syncServiceProvider),
    );

@Riverpod(keepAlive: true)
SignUpUseCase signUpUseCase(Ref ref) => SignUpUseCase(
      ref.watch(authRepositoryProvider),
      ref.watch(syncServiceProvider),
    );

@Riverpod(keepAlive: true)
SignInWithGoogleUseCase signInWithGoogleUseCase(Ref ref) =>
    SignInWithGoogleUseCase(
      ref.watch(authRepositoryProvider),
      ref.watch(syncServiceProvider),
    );

@Riverpod(keepAlive: true)
SignOutUseCase signOutUseCase(Ref ref) =>
    SignOutUseCase(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
ResetPasswordUseCase resetPasswordUseCase(Ref ref) =>
    ResetPasswordUseCase(ref.watch(authRepositoryProvider));
