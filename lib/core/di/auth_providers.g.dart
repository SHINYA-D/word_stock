// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authStateHash() => r'322d1d24acdb2986167edc960917365000e0d820';

/// See also [authState].
@ProviderFor(authState)
final authStateProvider = StreamProvider<AppUser?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateRef = StreamProviderRef<AppUser?>;
String _$currentUserHash() => r'3db556da0b92c742a70203357263da3f45499b09';

/// See also [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = Provider<AppUser?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserRef = ProviderRef<AppUser?>;
String _$signInWithEmailUseCaseHash() =>
    r'933efedbe31aaf0ba5a07953250bb27ca5db7415';

/// See also [signInWithEmailUseCase].
@ProviderFor(signInWithEmailUseCase)
final signInWithEmailUseCaseProvider =
    Provider<SignInWithEmailUseCase>.internal(
  signInWithEmailUseCase,
  name: r'signInWithEmailUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$signInWithEmailUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignInWithEmailUseCaseRef = ProviderRef<SignInWithEmailUseCase>;
String _$signUpUseCaseHash() => r'c7cd08fbb921f342817624ded583b70a600f4eb6';

/// See also [signUpUseCase].
@ProviderFor(signUpUseCase)
final signUpUseCaseProvider = Provider<SignUpUseCase>.internal(
  signUpUseCase,
  name: r'signUpUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$signUpUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignUpUseCaseRef = ProviderRef<SignUpUseCase>;
String _$signInWithGoogleUseCaseHash() =>
    r'90789a2d7c98156d5f79d3f503e8cbe00f780594';

/// See also [signInWithGoogleUseCase].
@ProviderFor(signInWithGoogleUseCase)
final signInWithGoogleUseCaseProvider =
    Provider<SignInWithGoogleUseCase>.internal(
  signInWithGoogleUseCase,
  name: r'signInWithGoogleUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$signInWithGoogleUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignInWithGoogleUseCaseRef = ProviderRef<SignInWithGoogleUseCase>;
String _$signOutUseCaseHash() => r'0f3b8d96db38125057aabad192372a78dfc498d2';

/// See also [signOutUseCase].
@ProviderFor(signOutUseCase)
final signOutUseCaseProvider = Provider<SignOutUseCase>.internal(
  signOutUseCase,
  name: r'signOutUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$signOutUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignOutUseCaseRef = ProviderRef<SignOutUseCase>;
String _$resetPasswordUseCaseHash() =>
    r'be0faeedfe83b966031bcde9d535f5b93e5e8d1f';

/// See also [resetPasswordUseCase].
@ProviderFor(resetPasswordUseCase)
final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>.internal(
  resetPasswordUseCase,
  name: r'resetPasswordUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$resetPasswordUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ResetPasswordUseCaseRef = ProviderRef<ResetPasswordUseCase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
