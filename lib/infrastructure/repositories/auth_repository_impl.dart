import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';
import 'package:word_stock/infrastructure/data_sources/firebase_auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final FirebaseAuthDataSource _dataSource;

  @override
  Stream<AppUser?> get authStateChanges {
    return _dataSource.authStateChanges.map(
      (user) => user == null ? null : _toAppUser(user),
    );
  }

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Right(_toAppUser(result.user!));
    } on FirebaseAuthException catch (e) {
      return Left(_mapFirebaseAuthException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _dataSource.signUpWithEmail(
        email: email,
        password: password,
      );
      return Right(_toAppUser(result.user!));
    } on FirebaseAuthException catch (e) {
      return Left(_mapFirebaseAuthException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    try {
      final result = await _dataSource.signInWithGoogle();
      return Right(_toAppUser(result.user!));
    } on FirebaseAuthException catch (e) {
      return Left(_mapFirebaseAuthException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _dataSource.signOut();
      return const Right(unit);
    } on FirebaseAuthException catch (e) {
      return Left(_mapFirebaseAuthException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _dataSource.sendPasswordResetEmail(email: email);
      return const Right(unit);
    } on FirebaseAuthException catch (e) {
      return Left(_mapFirebaseAuthException(e));
    } catch (e) {
      return Left(Failure.unknown(e.toString()));
    }
  }

  AppUser _toAppUser(User user) {
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }

  Failure _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return const Failure.network();
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'email-already-in-use':
        return const Failure.auth();
      default:
        return Failure.unknown(e.message ?? e.code);
    }
  }
}
