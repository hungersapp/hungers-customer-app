import 'package:customer_app/core/services/phone_dialer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records what [UrlLauncherPhoneDialerService] actually asked the platform
/// to launch, without ever placing a real call. Standard url_launcher test
/// double pattern (Fake + MockPlatformInterfaceMixin bypasses the plugin
/// token check).
class _RecordingUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;
  bool launchResult = true;
  int launchCalls = 0;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchCalls++;
    launchedUrl = url;
    return launchResult;
  }
}

void main() {
  late _RecordingUrlLauncherPlatform platform;
  late UrlLauncherPhoneDialerService dialer;

  setUp(() {
    platform = _RecordingUrlLauncherPlatform();
    UrlLauncherPlatform.instance = platform;
    dialer = const UrlLauncherPhoneDialerService();
  });

  test('a valid phone number opens a tel: URI for exactly that number', () async {
    final result = await dialer.call('9876543210');

    expect(result, isTrue);
    expect(platform.launchedUrl, 'tel:9876543210');
    expect(platform.launchCalls, 1);
  });

  test('an already-formatted number (e.g. +91) is passed through unchanged', () async {
    await dialer.call('+919876543210');

    expect(platform.launchedUrl, 'tel:+919876543210');
  });

  test('surrounding whitespace is trimmed before building the URI', () async {
    await dialer.call('  9876543210  ');

    expect(platform.launchedUrl, 'tel:9876543210');
  });

  test('an empty phone number never reaches the platform', () async {
    final result = await dialer.call('');

    expect(result, isFalse);
    expect(platform.launchCalls, 0);
  });

  test('a whitespace-only phone number never reaches the platform', () async {
    final result = await dialer.call('   ');

    expect(result, isFalse);
    expect(platform.launchCalls, 0);
  });

  test('does not crash and returns false when the platform launch fails', () async {
    platform.launchResult = false;

    final result = await dialer.call('9876543210');

    expect(result, isFalse);
  });

  test('does not crash and returns false when the platform throws', () async {
    UrlLauncherPlatform.instance = _ThrowingUrlLauncherPlatform();

    final result = await dialer.call('9876543210');

    expect(result, isFalse);
  });
}

class _ThrowingUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) {
    throw Exception('no dialer app available');
  }
}
