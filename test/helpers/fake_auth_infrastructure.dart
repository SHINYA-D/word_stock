// AuthRepositoryImpl 専用の手書きフェイク。
//
// `FirebaseAuthDataSource` は具象クラス（インターフェースではない）で、内部で
// `FirebaseAuth` / `GoogleSignIn` の実インスタンスをコンストラクタで要求するため、
// そのままではユニットテストで生成できない。
// Dart の暗黙のインターフェースを利用し、公開メンバーのみを `implements` した
// フェイクに差し替える。
//
// `User` / `UserCredential` も同様に firebase_auth パッケージの具象クラスで
// private コンストラクタしか持たないため、`noSuchMethod` にフォールバックする
// 最小限のフェイクを用意し、AuthRepositoryImpl が実際に参照する
// `uid` / `email` / `displayName` / `user` のみを override する。
import 'package:firebase_auth/firebase_auth.dart';
import 'package:word_stock/infrastructure/data_sources/firebase_auth_data_source.dart';

class FakeUser implements User {
  FakeUser({required this.uid, this.email, this.displayName});

  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuthDataSource implements FirebaseAuthDataSource {
  Stream<User?> authStateChangesOverride = const Stream.empty();

  Future<UserCredential> Function()? signInWithEmailImpl;
  Future<UserCredential> Function()? signUpWithEmailImpl;
  Future<UserCredential> Function()? signInWithGoogleImpl;
  Future<void> Function()? signOutImpl;
  Future<void> Function()? sendPasswordResetEmailImpl;

  @override
  Stream<User?> get authStateChanges => authStateChangesOverride;

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    final impl = signInWithEmailImpl;
    if (impl == null) {
      throw StateError('signInWithEmailImpl is not set');
    }
    return impl();
  }

  @override
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    final impl = signUpWithEmailImpl;
    if (impl == null) {
      throw StateError('signUpWithEmailImpl is not set');
    }
    return impl();
  }

  @override
  Future<UserCredential> signInWithGoogle() {
    final impl = signInWithGoogleImpl;
    if (impl == null) {
      throw StateError('signInWithGoogleImpl is not set');
    }
    return impl();
  }

  @override
  Future<void> signOut() {
    final impl = signOutImpl;
    if (impl == null) {
      return Future.value();
    }
    return impl();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    final impl = sendPasswordResetEmailImpl;
    if (impl == null) {
      return Future.value();
    }
    return impl();
  }
}
