import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Records every enable/disable call made through [WakelockPlus] during a
/// test, without touching any real platform channel. Installed via
/// `wakelockPlusPlatformInstance = FakeWakelockPlusPlatform()` in `setUp`.
class FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  bool _enabled = false;
  int enableCallCount = 0;
  int disableCallCount = 0;

  bool get isEnabledNow => _enabled;

  @override
  Future<void> toggle({required bool enable}) async {
    _enabled = enable;
    if (enable) {
      enableCallCount++;
    } else {
      disableCallCount++;
    }
  }

  @override
  Future<bool> get enabled async => _enabled;
}
