import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/presentation/providers/location_provider.dart';
import '../data/datasource/firebase_auth_datasource.dart';
import '../data/datasources/customer_profile_firestore_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/auth_user.dart';
import '../domain/phone_otp_session.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/create_customer_profile_usecase.dart';
import '../domain/usecases/get_customer_profile_usecase.dart';
import '../domain/usecases/google_signin_usecase.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/register_usecase.dart';
import '../domain/usecases/send_phone_otp_usecase.dart';
import '../domain/usecases/update_customer_profile_name_usecase.dart';
import '../domain/usecases/verify_phone_otp_usecase.dart';

final _datasourceProvider = Provider<FirebaseAuthDatasource>(
  (ref) => FirebaseAuthDatasource(),
);

final customerProfileDatasourceProvider =
    Provider<CustomerProfileFirestoreDatasource>(
  (ref) => CustomerProfileFirestoreDatasource(
    ref.watch(firestoreProvider),
  ),
);

final _repositoryProvider = Provider<AuthRepositoryImpl>(
  (ref) => AuthRepositoryImpl(
    ref.read(_datasourceProvider),
    profileDatasource: ref.watch(customerProfileDatasourceProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(_repositoryProvider),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.read(_repositoryProvider)),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(ref.read(_repositoryProvider)),
);

final googleSignInUseCaseProvider = Provider<GoogleSignInUseCase>(
  (ref) => GoogleSignInUseCase(ref.read(_repositoryProvider)),
);

final sendPhoneOtpUseCaseProvider = Provider<SendPhoneOtpUseCase>(
  (ref) => SendPhoneOtpUseCase(ref.read(_repositoryProvider)),
);

final verifyPhoneOtpUseCaseProvider = Provider<VerifyPhoneOtpUseCase>(
  (ref) => VerifyPhoneOtpUseCase(ref.read(_repositoryProvider)),
);

final getCustomerProfileUseCaseProvider = Provider<GetCustomerProfileUseCase>(
  (ref) => GetCustomerProfileUseCase(ref.read(_repositoryProvider)),
);

final createCustomerProfileUseCaseProvider =
    Provider<CreateCustomerProfileUseCase>(
  (ref) => CreateCustomerProfileUseCase(ref.read(_repositoryProvider)),
);

final updateCustomerProfileNameUseCaseProvider =
    Provider<UpdateCustomerProfileNameUseCase>(
  (ref) => UpdateCustomerProfileNameUseCase(ref.read(_repositoryProvider)),
);

class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;
  PhoneOtpSession? _otpSession;
  DateTime? _resendAvailableAt;

  PhoneOtpSession? get otpSession => _otpSession;

  Duration get resendCooldownRemaining {
    final until = _resendAvailableAt;
    if (until == null) {
      return Duration.zero;
    }
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canResendOtp => resendCooldownRemaining == Duration.zero;

  Future<PhoneOtpSession> sendPhoneOtp(String mobileNumber) async {
    state = const AsyncLoading();
    try {
      final session = await _ref.read(sendPhoneOtpUseCaseProvider)(
        mobileNumber: mobileNumber,
      );
      _otpSession = session;
      _resendAvailableAt = DateTime.now().add(const Duration(seconds: 30));
      if (session.autoVerifiedUser != null) {
        state = AsyncData(session.autoVerifiedUser);
      } else {
        state = const AsyncData(null);
      }
      return session;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<PhoneOtpSession> resendPhoneOtp() async {
    final session = _otpSession;
    if (session == null) {
      throw Exception('OTP session expired. Please request a new code.');
    }
    if (!canResendOtp) {
      throw Exception('Please wait before requesting another OTP.');
    }
    state = const AsyncLoading();
    try {
      final next = await _ref.read(sendPhoneOtpUseCaseProvider)(
        mobileNumber: session.phoneE164,
        resend: true,
        existingE164: session.phoneE164,
      );
      _otpSession = next;
      _resendAvailableAt = DateTime.now().add(const Duration(seconds: 30));
      if (next.autoVerifiedUser != null) {
        state = AsyncData(next.autoVerifiedUser);
      } else {
        state = const AsyncData(null);
      }
      return next;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<AuthUser> verifyPhoneOtp(String smsCode) async {
    state = const AsyncLoading();
    try {
      final user = await _ref.read(verifyPhoneOtpUseCaseProvider)(smsCode);
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void clearOtpSession() {
    _otpSession = null;
    _resendAvailableAt = null;
  }

  Future<AuthUser?> loadCustomerProfile(String userId) async {
    final profile = await _ref.read(getCustomerProfileUseCaseProvider)(userId);
    final current = state.valueOrNull;
    if (profile != null && current != null && current.uid == userId) {
      state = AsyncData(
        current.copyWith(
          name: profile.name ?? current.name,
          email: profile.email ?? current.email,
          mobileNumber: profile.mobileNumber ?? current.mobileNumber,
          photoUrl: profile.photoUrl ?? current.photoUrl,
        ),
      );
    }
    return profile;
  }

  Future<AuthUser> updateCustomerProfileName(String name) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('You must be signed in to save your name.');
    }
    final updated = await _ref.read(updateCustomerProfileNameUseCaseProvider)(
      userId: userId,
      name: name,
    );
    final current = state.valueOrNull;
    if (current != null && current.uid == updated.uid) {
      state = AsyncData(current.copyWith(name: updated.name));
    } else {
      state = AsyncData(updated);
    }
    return updated;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _ref.read(loginUseCaseProvider)(
        email: email,
        password: password,
      );
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _ref.read(registerUseCaseProvider)(
        name: name,
        email: email,
        mobileNumber: mobileNumber,
        password: password,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _ref.read(googleSignInUseCaseProvider)();
    });
  }

  Future<void> logout() async {
    await _ref.read(_repositoryProvider).logout();
    clearOtpSession();
    state = const AsyncData(null);
  }

  Future<void> loadCurrentUser() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _ref.read(_repositoryProvider).getCurrentUser();
      if (session == null) {
        return null;
      }
      final profile = await _ref.read(getCustomerProfileUseCaseProvider)(
        session.uid,
      );
      if (profile == null) {
        return session;
      }
      return session.copyWith(
        name: profile.name ?? session.name,
        email: profile.email ?? session.email,
        mobileNumber: profile.mobileNumber ?? session.mobileNumber,
        photoUrl: profile.photoUrl ?? session.photoUrl,
      );
    });
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _ref
        .read(_repositoryProvider)
        .sendPasswordResetEmail(email: email);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>(
  (ref) => AuthNotifier(ref),
);

/// Emits the Firebase Auth user, including after browser refresh / app restart.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Stable authenticated user ID for cart persistence.
final currentUserIdProvider = Provider<String?>((ref) {
  final authUser = ref.watch(authProvider).valueOrNull;
  if (authUser != null) {
    return authUser.uid;
  }

  final streamUser = ref.watch(authStateChangesProvider).valueOrNull;
  return streamUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
});

/// Profile display source. Reuses [AuthUser], including after browser refresh.
final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  final authUser = ref.watch(authProvider).valueOrNull;
  if (authUser != null) {
    return authUser;
  }

  final user = ref.watch(authStateChangesProvider).valueOrNull ??
      FirebaseAuth.instance.currentUser;
  if (user == null) {
    return null;
  }

  return AuthUser(
    uid: user.uid,
    name: user.displayName,
    email: user.email,
    mobileNumber: user.phoneNumber,
    photoUrl: user.photoURL,
    emailVerified: user.emailVerified,
    isAnonymous: user.isAnonymous,
  );
});
