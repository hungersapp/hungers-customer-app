import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasource/firebase_auth_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/google_signin_usecase.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/register_usecase.dart';

/// Datasource
final firebaseAuthDatasourceProvider = Provider<FirebaseAuthDatasource>(
  (ref) => FirebaseAuthDatasource(),
);

/// Repository
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.read(firebaseAuthDatasourceProvider),
  ),
);

/// UseCases
final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(
    ref.read(authRepositoryProvider),
  ),
);

final registerUseCaseProvider = Provider<RegisterUseCase>(
  (ref) => RegisterUseCase(
    ref.read(authRepositoryProvider),
  ),
);

final googleSignInUseCaseProvider = Provider<GoogleSignInUseCase>(
  (ref) => GoogleSignInUseCase(
    ref.read(authRepositoryProvider),
  ),
);
