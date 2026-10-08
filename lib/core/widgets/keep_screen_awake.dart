import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Prevents the OS foreground screen-timeout from sleeping/locking the
/// device while [keepAwake] is true, without ever touching the rest of
/// the app — no global wakelock, no background execution, and it never
/// interferes with the user manually locking the phone (wakelock APIs
/// only suppress automatic idle-timeout of the foreground activity).
///
/// Toggling [keepAwake] (e.g. an order leaving/entering an ongoing
/// status) enables/disables the wakelock accordingly, and leaving this
/// widget's part of the tree (screen popped, tab switched away) always
/// disables it via [dispose] — so a wakelock can never outlive the
/// screen that requested it. Enable/disable calls are only ever made on
/// an actual transition (tracked via [_enabled]), never redundantly.
class KeepScreenAwakeWhile extends StatefulWidget {
  const KeepScreenAwakeWhile({
    super.key,
    required this.keepAwake,
    required this.child,
  });

  final bool keepAwake;
  final Widget child;

  @override
  State<KeepScreenAwakeWhile> createState() => _KeepScreenAwakeWhileState();
}

class _KeepScreenAwakeWhileState extends State<KeepScreenAwakeWhile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _sync(widget.keepAwake);
  }

  @override
  void didUpdateWidget(covariant KeepScreenAwakeWhile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAwake != widget.keepAwake) {
      _sync(widget.keepAwake);
    }
  }

  void _sync(bool keepAwake) {
    if (keepAwake == _enabled) {
      return;
    }
    _enabled = keepAwake;
    if (keepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    if (_enabled) {
      _enabled = false;
      WakelockPlus.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
