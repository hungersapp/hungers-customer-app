import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/domain/entities/auth_user.dart';
import 'package:customer_app/features/authentication/domain/phone_otp_session.dart';
import 'package:customer_app/features/authentication/domain/repositories/auth_repository.dart';
import 'package:customer_app/features/authentication/domain/usecases/update_customer_profile_name_usecase.dart';
import 'package:customer_app/features/authentication/providers/auth_provider.dart';
import 'package:customer_app/features/profile/presentation/screens/edit_profile_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.writeError});

  Object? writeError;
  AuthUser profile = const AuthUser(
    uid: 'user-1',
    name: 'Priya Kumar',
    mobileNumber: '9876543210',
    email: 'priya@example.com',
    emailVerified: true,
    isAnonymous: false,
  );
  int writeCalls = 0;

  @override
  Future<void> updateCustomerProfileName({
    required String userId,
    required String name,
  }) async {
    writeCalls += 1;
    if (writeError != null) {
      throw writeError!;
    }
    profile = profile.copyWith(name: name);
  }

  @override
  Future<AuthUser?> getCustomerProfile(String userId) async => profile;

  @override
  Future<AuthUser?> getCurrentUser() async => profile;

  @override
  Future<void> createCustomerProfile(AuthUser user) async {}

  @override
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneE164,
    bool resend = false,
  }) async => PhoneOtpSession(phoneE164: phoneE164);

  @override
  Future<AuthUser> verifyPhoneOtp({required String smsCode}) async => profile;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => profile;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async => profile;

  @override
  Future<AuthUser> signInWithGoogle() async => profile;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

Widget _app(_FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('user-1'),
      currentAuthUserProvider.overrideWithValue(repository.profile),
      updateCustomerProfileNameUseCaseProvider.overrideWithValue(
        UpdateCustomerProfileNameUseCase(repository),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              child: const Text('Open edit'),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Open edit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('valid name save shows success and pops', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_app(repository));
    await _openEditor(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Ananya Devi');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.writeCalls, 1);
    expect(repository.profile.name, 'Ananya Devi');
    expect(find.text('Name saved.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('empty name is blocked without a write', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_app(repository));
    await _openEditor(tester);

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.writeCalls, 0);
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('Firestore failure stays on the screen with an error', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      writeError: Exception('unavailable'),
    );
    await tester.pumpWidget(_app(repository));
    await _openEditor(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Ananya Devi');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.writeCalls, 1);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      find.text('Unable to save your name. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid short name is rejected without a write', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_app(repository));
    await _openEditor(tester);

    await tester.enterText(find.byType(TextFormField).first, 'A');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.writeCalls, 0);
    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('duplicate Save taps issue a single write', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_app(repository));
    await _openEditor(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Ananya Devi');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.writeCalls, 1);
  });
}
