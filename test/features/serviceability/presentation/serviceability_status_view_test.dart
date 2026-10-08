import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/serviceability/presentation/providers/serviceability_provider.dart';
import 'package:customer_app/features/serviceability/presentation/widgets/serviceability_status_view.dart';

Widget _app(
  ServiceabilityState state, {
  VoidCallback? onRetry,
  VoidCallback? onChangeLocation,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ServiceabilityStatusView(
        state: state,
        onRetry: onRetry ?? () {},
        onChangeLocation: onChangeLocation ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('initial state asks the customer to choose a delivery location', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(const ServiceabilityState(), onChangeLocation: () => opened += 1),
    );

    expect(find.text('Choose your delivery location'), findsOneWidget);
    // Location is chosen (current location / search), never typed as a
    // bare pincode.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Checking availability...'), findsNothing);

    await tester.tap(find.text('Choose location'));
    expect(opened, 1);
  });

  testWidgets('checking state does not show restaurants copy', (tester) async {
    await tester.pumpWidget(
      _app(
        const ServiceabilityState(
          status: ServiceabilityUiStatus.checking,
          pincode: '613403',
        ),
      ),
    );

    expect(find.text('Checking availability...'), findsOneWidget);
    expect(find.text('Choose your delivery location'), findsNothing);
  });

  testWidgets('serviceable state does not show a bulky availability card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ServiceabilityState(
          status: ServiceabilityUiStatus.serviceable,
          pincode: '613403',
        ),
      ),
    );

    expect(find.text('HUNGERS is available in your area.'), findsNothing);
    expect(find.textContaining('is available in your area'), findsNothing);
    expect(find.text('Choose your delivery location'), findsNothing);
  });

  testWidgets('not-serviceable state says no restaurants are available in '
      'this location, hides internal zone details, and offers a new location', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(
        const ServiceabilityState(
          status: ServiceabilityUiStatus.notServiceable,
          pincode: '999999',
        ),
        onChangeLocation: () => opened += 1,
      ),
    );

    expect(
      find.text('Sorry, no restaurants available in this location.'),
      findsOneWidget,
    );
    expect(
      find.text('Tukkito is not available in this area yet.'),
      findsNothing,
    );
    expect(
      find.text('HUNGERS is not available in this area yet.'),
      findsNothing,
    );
    expect(find.textContaining('zone'), findsNothing);
    expect(find.text('Retry'), findsNothing);

    await tester.tap(find.text('Change location'));
    expect(opened, 1);
  });

  testWidgets('error state is not labeled not serviceable and offers retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      _app(
        const ServiceabilityState(
          status: ServiceabilityUiStatus.error,
          pincode: '613403',
        ),
        onRetry: () => retried = true,
      ),
    );

    expect(
      find.text('Unable to check availability. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.text('Sorry, no restaurants available in this location.'),
      findsNothing,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets(
    'an unreadable pincode asks the customer to choose the location again',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const ServiceabilityState(
            status: ServiceabilityUiStatus.invalidPincode,
            pincode: '12',
          ),
        ),
      );

      expect(find.text('Choose your delivery location'), findsOneWidget);
      expect(find.textContaining('valid pincode'), findsOneWidget);
      expect(find.text('Checking availability...'), findsNothing);
    },
  );
}
