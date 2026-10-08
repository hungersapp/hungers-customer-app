import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/validators/indian_mobile.dart';
import 'package:customer_app/features/authentication/presentation/pages/login_screen.dart';

void main() {
  testWidgets('mobile login validates before sending OTP', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Welcome to Tukkito'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('New Customer?'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(find.text(IndianMobile.invalidMessage), findsOneWidget);
  });

  testWidgets(
    'Create Account stays on mobile OTP and does not open email registration',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text(IndianMobile.invalidMessage), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Please enter password'), findsNothing);
    },
  );
}
