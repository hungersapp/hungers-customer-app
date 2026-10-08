import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/authentication/presentation/pages/otp_screen.dart';

void main() {
  testWidgets('OTP screen asks for 6 digits and supports change number', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OtpScreen())),
    );

    expect(find.text('OTP Verification'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Resend OTP'), findsOneWidget);
    expect(find.text('Change mobile number'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
  });
}
