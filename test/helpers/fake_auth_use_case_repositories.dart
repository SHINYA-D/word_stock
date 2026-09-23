import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/domain/repositories/auth_repository.dart';
import 'package:word_stock/infrastructure/data_sources/local/database_helper.dart';
import 'package:word_stock/infrastructure/data_sources/local/sync_queue_data_source.dart';
import 'package:word_stock/infrastructure/sync/sync_service.dart';

/// `lib/application/use_cases/auth/**` のテストで共有する手書き Fake 群。
///
/// [AuthRepository] は呼び出し内容を記録しつつ、テストごとに任意の
/// `Either<Failure, T>` を返せるフェイクとして実装する。

class FakeAuthRepository implements AuthRepository {
  Either<Failure, AppUser> signInWithEmailResult =
      const Right(AppUser(id: 'u1', email: 'a@example.com'));
  Either<Failure, AppUser> signUpWithEmailResult =
      const Right(AppUser(id: 'u1', email: 'a@example.com'));
  Either<Failure, AppUser> signInWithGoogleResult =
      const Right(AppUser(id: 'u1', email: 'a@example.com'));
  Either<Failure, Unit> signOutResult = const Right(unit);
  Either<Failure, Unit> sendPasswordResetEmailResult = const Right(unit);

  int signInWithEmailCallCount = 0;
  int signUpWithEmailCallCount = 0;
  int signInWithGoogleCallCount = 0;
  int signOutCallCount = 0;
  int sendPasswordResetEmailCallCount = 0;

  ({String email, String password})? receivedSignInWithEmail;
  ({String email, String password})? receivedSignUpWithEmail;
  String? receivedResetPasswordEmail;

  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInWithEmailCallCount++;
    receivedSignInWithEmail = (email: email, password: password);
    return signInWithEmailResult;
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpWithEmailCallCount++;
    receivedSignUpWithEmail = (email: email, password: password);
    return signUpWithEmailResult;
  }

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    signInWithGoogleCallCount++;
    return signInWithGoogleResult;
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    signOutCallCount++;
    return signOutResult;
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    sendPasswordResetEmailCallCount++;
    receivedResetPasswordEmail = email;
    return sendPasswordResetEmailResult;
  }
}

/// [SyncService.syncRemoteToLocalOnLogin] の呼び出しを記録・制御するためのフェイク。
///
/// `SyncService` はインターフェースではなく具象クラスのため、
/// `test/infrastructure/sync/auto_sync_service_test.dart` の `FakeSyncService` と同様に
/// 実 Firestore/SQLite 通信を避けつつコンストラクタの型要件を満たし、
/// 対象メソッドのみをオーバーライドする。
class FakeSyncServiceForLogin extends SyncService {
  FakeSyncServiceForLogin()
      : super(
          syncQueueDataSource: SyncQueueDataSource(DatabaseHelper()),
          firestore: FakeFirebaseFirestore(),
          getCurrentUserId: () => 'test-user',
          dbHelper: DatabaseHelper(),
        );

  int syncRemoteToLocalOnLoginCallCount = 0;

  /// 設定すると次回呼び出し時にこの例外を投げる。
  Object? exceptionToThrow;

  @override
  Future<void> syncRemoteToLocalOnLogin() async {
    syncRemoteToLocalOnLoginCallCount++;
    final e = exceptionToThrow;
    if (e != null) throw e;
  }
}
