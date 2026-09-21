import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/app_user.dart';
import 'package:word_stock/infrastructure/repositories/auth_repository_impl.dart';

import '../../helpers/fake_auth_infrastructure.dart';

void main() {
  late FakeFirebaseAuthDataSource fakeDataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    fakeDataSource = FakeFirebaseAuthDataSource();
    repository = AuthRepositoryImpl(fakeDataSource);
  });

  group('signInWithEmail', () {
    test('メールとパスワードでのサインインに成功した場合、AppUserに変換されRightで返る', () async {
      fakeDataSource.signInWithEmailImpl = () async => FakeUserCredential(
            FakeUser(
              uid: 'uid-1',
              email: 'user@example.com',
              displayName: 'テストユーザー',
            ),
          );

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      expect(result.isRight(), isTrue);
      result.match(
        (_) => fail('Right が返るはず'),
        (user) => expect(
          user,
          const AppUser(
            id: 'uid-1',
            email: 'user@example.com',
            displayName: 'テストユーザー',
          ),
        ),
      );
    });

    test('サインインしたユーザーのemail/displayNameがnullの場合、'
        'emailは空文字に変換されdisplayNameはnullのまま返る', () async {
      fakeDataSource.signInWithEmailImpl = () async => FakeUserCredential(
            FakeUser(uid: 'uid-2', email: null, displayName: null),
          );

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (_) => fail('Right が返るはず'),
        (user) {
          expect(user.email, '');
          expect(user.displayName, isNull);
        },
      );
    });

    test('FirebaseAuthExceptionのcodeがnetwork-request-failedの場合、'
        'Failure.networkが返る', () async {
      fakeDataSource.signInWithEmailImpl = () async => throw FirebaseAuthException(
            code: 'network-request-failed',
          );

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthExceptionのcodeがuser-not-foundの場合、Failure.authが返る', () async {
      fakeDataSource.signInWithEmailImpl =
          () async => throw FirebaseAuthException(code: 'user-not-found');

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthExceptionのcodeがwrong-passwordの場合、Failure.authが返る', () async {
      fakeDataSource.signInWithEmailImpl =
          () async => throw FirebaseAuthException(code: 'wrong-password');

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthExceptionのcodeがinvalid-credentialの場合、Failure.authが返る', () async {
      fakeDataSource.signInWithEmailImpl =
          () async => throw FirebaseAuthException(code: 'invalid-credential');

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthExceptionのcodeがemail-already-in-useの場合、Failure.authが返る',
        () async {
      fakeDataSource.signInWithEmailImpl =
          () async => throw FirebaseAuthException(code: 'email-already-in-use');

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthExceptionのcodeが未知でmessageがある場合、'
        'Failure.unknown(message)が返る', () async {
      fakeDataSource.signInWithEmailImpl = () async => throw FirebaseAuthException(
            code: 'some-unmapped-code',
            message: '想定外のエラーメッセージ',
          );

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) =>
            expect(failure, const Failure.unknown('想定外のエラーメッセージ')),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthExceptionのcodeが未知でmessageがnullの場合、'
        'Failure.unknown(code)が返る', () async {
      fakeDataSource.signInWithEmailImpl = () async => throw FirebaseAuthException(
            code: 'some-unmapped-code',
          );

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) =>
            expect(failure, const Failure.unknown('some-unmapped-code')),
        (_) => fail('Left が返るはず'),
      );
    });

    test('FirebaseAuthException以外の例外が発生した場合、'
        'Failure.unknown(例外文字列)が返る', () async {
      fakeDataSource.signInWithEmailImpl =
          () async => throw StateError('予期しないエラー');

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      result.match(
        (failure) => expect(
          failure,
          Failure.unknown(StateError('予期しないエラー').toString()),
        ),
        (_) => fail('Left が返るはず'),
      );
    });

    test('UserCredentialのuserがnullの場合、Failure.unknownが返る', () async {
      fakeDataSource.signInWithEmailImpl =
          () async => FakeUserCredential(null);

      final result = await repository.signInWithEmail(
        email: 'user@example.com',
        password: 'password',
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('signUpWithEmail', () {
    test('サインアップに成功した場合、AppUserに変換されRightで返る', () async {
      fakeDataSource.signUpWithEmailImpl = () async => FakeUserCredential(
            FakeUser(uid: 'uid-3', email: 'new@example.com'),
          );

      final result = await repository.signUpWithEmail(
        email: 'new@example.com',
        password: 'password',
      );

      result.match(
        (_) => fail('Right が返るはず'),
        (user) => expect(
          user,
          const AppUser(id: 'uid-3', email: 'new@example.com'),
        ),
      );
    });

    test('FirebaseAuthExceptionのcodeがemail-already-in-useの場合、Failure.authが返る',
        () async {
      fakeDataSource.signUpWithEmailImpl =
          () async => throw FirebaseAuthException(code: 'email-already-in-use');

      final result = await repository.signUpWithEmail(
        email: 'new@example.com',
        password: 'password',
      );

      result.match(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('signInWithGoogle', () {
    test('Google認証に成功した場合、AppUserに変換されRightで返る', () async {
      fakeDataSource.signInWithGoogleImpl = () async => FakeUserCredential(
            FakeUser(uid: 'uid-4', email: 'google@example.com'),
          );

      final result = await repository.signInWithGoogle();

      result.match(
        (_) => fail('Right が返るはず'),
        (user) => expect(
          user,
          const AppUser(id: 'uid-4', email: 'google@example.com'),
        ),
      );
    });

    test('Google認証がキャンセルされた場合、未知のコードとしてFailure.unknownが返る', () async {
      fakeDataSource.signInWithGoogleImpl = () async => throw FirebaseAuthException(
            code: 'sign_in_cancelled',
            message: 'Google sign in was cancelled.',
          );

      final result = await repository.signInWithGoogle();

      result.match(
        (failure) => expect(
          failure,
          const Failure.unknown('Google sign in was cancelled.'),
        ),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('signOut', () {
    test('サインアウトに成功した場合、Right(unit)が返る', () async {
      final result = await repository.signOut();

      expect(result.isRight(), isTrue);
    });

    test('サインアウト中にFirebaseAuthExceptionが発生した場合、対応するFailureが返る', () async {
      fakeDataSource.signOutImpl =
          () async => throw FirebaseAuthException(code: 'network-request-failed');

      final result = await repository.signOut();

      result.match(
        (failure) => expect(failure, const Failure.network()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('sendPasswordResetEmail', () {
    test('パスワードリセットメール送信に成功した場合、Right(unit)が返る', () async {
      final result = await repository.sendPasswordResetEmail(
        email: 'user@example.com',
      );

      expect(result.isRight(), isTrue);
    });

    test('FirebaseAuthExceptionのcodeがuser-not-foundの場合、Failure.authが返る', () async {
      fakeDataSource.sendPasswordResetEmailImpl =
          () async => throw FirebaseAuthException(code: 'user-not-found');

      final result = await repository.sendPasswordResetEmail(
        email: 'user@example.com',
      );

      result.match(
        (failure) => expect(failure, const Failure.auth()),
        (_) => fail('Left が返るはず'),
      );
    });
  });

  group('authStateChanges', () {
    test('認証状態変化のストリームにユーザーが流れた場合、AppUserに変換されて流れる', () async {
      fakeDataSource.authStateChangesOverride = Stream.value(
        FakeUser(uid: 'uid-5', email: 'stream@example.com'),
      );
      repository = AuthRepositoryImpl(fakeDataSource);

      final emitted = await repository.authStateChanges.first;

      expect(
        emitted,
        const AppUser(id: 'uid-5', email: 'stream@example.com'),
      );
    });

    test('認証状態変化のストリームにnullが流れた場合、nullがそのまま流れる', () async {
      fakeDataSource.authStateChangesOverride = Stream.value(null);
      repository = AuthRepositoryImpl(fakeDataSource);

      final emitted = await repository.authStateChanges.first;

      expect(emitted, isNull);
    });
  });
}
