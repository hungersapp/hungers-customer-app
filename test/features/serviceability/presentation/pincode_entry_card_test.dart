import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/domain/indian_pincode.dart';
import 'package:customer_app/features/serviceability/presentation/widgets/pincode_entry_card.dart';

void main() {
  testWidgets('does not submit an invalid pincode', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PincodeEntryCard(onSubmit: (value) => submitted = value),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Check availability'));
    await tester.pump();

    expect(submitted, isNull);
    expect(find.text(IndianPincode.invalidMessage), findsOneWidget);
  });

  testWidgets('submits a valid 6-digit pincode', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PincodeEntryCard(onSubmit: (value) => submitted = value),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '613403');
    await tester.tap(find.text('Check availability'));
    await tester.pump();

    expect(submitted, '613403');
    expect(find.text(IndianPincode.invalidMessage), findsNothing);
  });
}
