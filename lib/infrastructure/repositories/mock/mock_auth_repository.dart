import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';

/// 開発用インメモリ認証リポジトリ。
/// Firebase なしでアプリを起動・動作確認できる。
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  // 起動時は自動ログイン状態にする（開発効率のため）
  MockAuthRepository() {
    _currentUser = const AppUser(
      id: 'mock-user-id',
      email: 'dev@example.com',
      displayName: '開発ユーザー',
    );
  }

  @override
  Stream<AppUser?> get authStateChanges async* {
    // 現在のユーザー状態を即座に emit してから、以降の変化を流す
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = AppUser(
      id: 'mock-user-id',
      email: email,
      displayName: email.split('@').first,
    );
    _controller.add(_currentUser);
    return Right(_currentUser!);
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = AppUser(
      id: 'mock-user-id',
      email: email,
      displayName: email.split('@').first,
    );
    _controller.add(_currentUser);
    return Right(_currentUser!);
  }

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = const AppUser(
      id: 'mock-user-id',
      email: 'google@example.com',
      displayName: 'Google ユーザー',
    );
    _controller.add(_currentUser);
    return Right(_currentUser!);
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    _controller.add(null);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const Right(unit);
  }
}
