import 'package:url_launcher/url_launcher.dart';

/// Opens the device's native phone dialer pre-filled with a real phone
/// number. Direct calling only, for now — no masking, no relay number, no
/// telephony provider integration (that is a later phase). Backs "Call
/// Rider", the only call action in this app.
abstract class PhoneDialerService {
  /// Launches the dialer for [phoneNumber]. Returns false (never throws)
  /// when the number is empty/whitespace-only or no dialer app is
  /// available — callers must treat a false result as a recoverable,
  /// user-facing failure.
  Future<bool> call(String phoneNumber);
}

class UrlLauncherPhoneDialerService implements PhoneDialerService {
  const UrlLauncherPhoneDialerService();

  @override
  Future<bool> call(String phoneNumber) async {
    final trimmed = phoneNumber.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri(scheme: 'tel', path: trimmed);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
