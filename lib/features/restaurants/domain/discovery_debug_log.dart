import 'package:flutter/foundation.dart';

/// Temporary debug-only discovery traces. Stripped from release behaviour
/// (no extra queries, no fallback, no UI change).
void discoveryDebug(String message) {
  if (kDebugMode) {
    debugPrint('TUKKITO_DISCOVERY $message');
  }
}
