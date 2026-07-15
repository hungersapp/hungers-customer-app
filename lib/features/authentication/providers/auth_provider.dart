import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasource/firebase_auth_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/auth_user.dart';
import '../domain/usecases/google_signin_usecase.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/register_usecase.dart';

final _datasourceProvider = Provider<FirebaseAuthDatasource>(
  (ref) => FirebaseAuthDatasource(),
);

final _repositoryProvider = Provider<AuthRepositoryImpl>(
  (ref) => AuthRepositoryImpl(ref.read(_datasourceProvider)),
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

class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

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
    state = const AsyncData(null);
  }

  Future<void> loadCurrentUser() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _ref.read(_repositoryProvider).getCurrentUser();
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
