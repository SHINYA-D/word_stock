// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseAuthHash() => r'8c3e9d11b27110ca96130356b5ef4d5d34a5ffc2';

/// See also [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = Provider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthRef = ProviderRef<FirebaseAuth>;
String _$firestoreHash() => r'05d3b5fdb13af2444bcafa7fdfd877eed780dc2d';

/// オフライン対応は SQLite と同期キューで自前で行うため、Firestore SDK のオフライン機能は使わない
///
/// Copied from [firestore].
@ProviderFor(firestore)
final firestoreProvider = Provider<FirebaseFirestore>.internal(
  firestore,
  name: r'firestoreProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$firestoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreRef = ProviderRef<FirebaseFirestore>;
String _$googleSignInHash() => r'4df13ef226b172967e2ad6fef31c4648f6d52fd9';

/// See also [googleSignIn].
@ProviderFor(googleSignIn)
final googleSignInProvider = Provider<GoogleSignIn>.internal(
  googleSignIn,
  name: r'googleSignInProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$googleSignInHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GoogleSignInRef = ProviderRef<GoogleSignIn>;
String _$firebaseAuthDataSourceHash() =>
    r'330ac279dce4b510044c395b703781d678c2e7ce';

/// See also [firebaseAuthDataSource].
@ProviderFor(firebaseAuthDataSource)
final firebaseAuthDataSourceProvider =
    Provider<FirebaseAuthDataSource>.internal(
  firebaseAuthDataSource,
  name: r'firebaseAuthDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firebaseAuthDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthDataSourceRef = ProviderRef<FirebaseAuthDataSource>;
String _$firestoreDataSourceHash() =>
    r'57054aa72f7849231d78faeed8dd8510effb0a2a';

/// See also [firestoreDataSource].
@ProviderFor(firestoreDataSource)
final firestoreDataSourceProvider = Provider<FirestoreDataSource>.internal(
  firestoreDataSource,
  name: r'firestoreDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firestoreDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreDataSourceRef = ProviderRef<FirestoreDataSource>;
String _$syncRemoteDataSourceHash() =>
    r'0b83e0322ea8a6d5b0843004ed41ba90b3b04b8e';

/// See also [syncRemoteDataSource].
@ProviderFor(syncRemoteDataSource)
final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>.internal(
  syncRemoteDataSource,
  name: r'syncRemoteDataSourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncRemoteDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncRemoteDataSourceRef = ProviderRef<SyncRemoteDataSource>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
