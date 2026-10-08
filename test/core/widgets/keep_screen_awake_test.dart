import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:customer_app/core/widgets/keep_screen_awake.dart';

import '../../helpers/fake_wakelock_plus_platform.dart';

void main() {
  late FakeWakelockPlusPlatform fake;

  setUp(() {
    fake = FakeWakelockPlusPlatform();
    wakelockPlusPlatformInstance = fake;
  });

  Widget wrap({required bool keepAwake}) {
    return MaterialApp(
      home: KeepScreenAwakeWhile(
        keepAwake: keepAwake,
        child: const Scaffold(body: Text('screen')),
      ),
    );
  }

  testWidgets('mounting with keepAwake true enables the wakelock', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(keepAwake: true));
    await tester.pump();

    expect(fake.isEnabledNow, isTrue);
    expect(fake.enableCallCount, 1);
    expect(fake.disableCallCount, 0);
  });

  testWidgets('mounting with keepAwake false never enables the wakelock', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(keepAwake: false));
    await tester.pump();

    expect(fake.isEnabledNow, isFalse);
    expect(fake.enableCallCount, 0);
    expect(fake.disableCallCount, 0);
  });

  testWidgets(
    'keepAwake flipping true -> false disables the wakelock while still mounted',
    (tester) async {
      await tester.pumpWidget(wrap(keepAwake: true));
      await tester.pump();
      expect(fake.isEnabledNow, isTrue);

      await tester.pumpWidget(wrap(keepAwake: false));
      await tester.pump();

      expect(fake.isEnabledNow, isFalse);
      expect(fake.enableCallCount, 1);
      expect(fake.disableCallCount, 1);
    },
  );

  testWidgets('keepAwake flipping false -> true enables the wakelock', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(keepAwake: false));
    await tester.pump();

    await tester.pumpWidget(wrap(keepAwake: true));
    await tester.pump();

    expect(fake.isEnabledNow, isTrue);
    expect(fake.enableCallCount, 1);
  });

  testWidgets(
    'repeated identical keepAwake values never issue a duplicate toggle call',
    (tester) async {
      await tester.pumpWidget(wrap(keepAwake: true));
      await tester.pump();
      expect(fake.enableCallCount, 1);

      // Rebuilding with the SAME keepAwake value must not re-toggle.
      await tester.pumpWidget(wrap(keepAwake: true));
      await tester.pump();
      await tester.pumpWidget(wrap(keepAwake: true));
      await tester.pump();

      expect(fake.enableCallCount, 1);
      expect(fake.disableCallCount, 0);
    },
  );

  testWidgets(
    'leaving/disposing the widget while awake always disables the wakelock (no leaks)',
    (tester) async {
      await tester.pumpWidget(wrap(keepAwake: true));
      await tester.pump();
      expect(fake.isEnabledNow, isTrue);

      // Replace the entire tree, disposing KeepScreenAwakeWhile.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('elsewhere'))),
      );
      await tester.pump();

      expect(
        fake.isEnabledNow,
        isFalse,
        reason: 'no wakelock may remain enabled after leaving the screen',
      );
      expect(fake.disableCallCount, 1);
    },
  );

  testWidgets('disposing while already off issues no extra disable call', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(keepAwake: false));
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('elsewhere'))),
    );
    await tester.pump();

    expect(fake.disableCallCount, 0);
  });
}
