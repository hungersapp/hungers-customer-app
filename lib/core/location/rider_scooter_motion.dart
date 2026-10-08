import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';

import 'bearing_calculator.dart';

/// Visual-only. Fixes closer than this are GPS noise, not a new ride.
const double riderScooterJitterMeters = 3;

/// Accuracy may widen the hold, but never enough to swallow a real move.
const double riderScooterMaxAccuracyHoldMeters = 8;

const Duration riderScooterMinMoveDuration = Duration(milliseconds: 450);
const Duration riderScooterMaxMoveDuration = Duration(milliseconds: 1200);

class RiderScooterPose {
  const RiderScooterPose({
    required this.latitude,
    required this.longitude,
    required this.heading,
  });

  final double latitude;
  final double longitude;

  /// Degrees clockwise from north. May sit outside 0–360 while a short
  /// turn such as 350° → 10° is in progress, so the marker does not spin
  /// the long way.
  final double heading;
}

class _ScooterSegment {
  const _ScooterSegment({
    required this.from,
    required this.to,
    required this.startedAt,
    required this.duration,
  });

  final RiderScooterPose from;
  final RiderScooterPose to;
  final DateTime startedAt;
  final Duration duration;
}

/// Glides the rider marker between accepted GPS poses.
///
/// This does not read Firebase or device GPS. Callers pass fixes that
/// already came from the existing location stream. Older samples are
/// ignored, tiny jitter does not start a ride, and a stale or stopped
/// rider freezes instead of coasting.
class RiderScooterMotion extends ChangeNotifier {
  RiderScooterPose? _presented;
  RiderScooterPose? _target;
  DateTime? _lastSampleTime;
  _ScooterSegment? _segment;
  bool _disposed = false;
  bool _stale = false;

  bool get isDisposed => _disposed;
  bool get isAnimating => _segment != null;
  bool get isStale => _stale;
  RiderScooterPose? get pose => _presented;

  /// Returns true when a new ride toward [latitude]/[longitude] starts,
  /// or when the first pose is placed. Duplicate, jitter, stale, stopped,
  /// and out-of-order samples return false.
  bool offer({
    required double latitude,
    required double longitude,
    required double heading,
    required DateTime now,
    DateTime? sampleTime,
    double? accuracyMeters,
    bool stale = false,
    bool stopped = false,
  }) {
    if (_disposed) {
      return false;
    }
    if (sampleTime != null &&
        _lastSampleTime != null &&
        sampleTime.isBefore(_lastSampleTime!)) {
      return false;
    }

    final incoming = RiderScooterPose(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
    );

    if (stale) {
      _freeze(_sample(now) ?? incoming, sampleTime, stale: true);
      return false;
    }

    if (stopped) {
      _freeze(_sample(now) ?? incoming, sampleTime, stale: false);
      return false;
    }

    if (_target != null) {
      final moved = Geolocator.distanceBetween(
        _target!.latitude,
        _target!.longitude,
        latitude,
        longitude,
      );
      if (moved < _jitterHold(accuracyMeters)) {
        return false;
      }
    }

    final previousSample = _lastSampleTime;
    if (sampleTime != null) {
      _lastSampleTime = sampleTime;
    }

    if (_target == null) {
      _presented = incoming;
      _target = incoming;
      _segment = null;
      _stale = false;
      _notify();
      return true;
    }

    final from = _sample(now) ?? incoming;
    final delta = shortestHeadingDelta(from.heading, heading);
    final to = RiderScooterPose(
      latitude: latitude,
      longitude: longitude,
      heading: from.heading + delta,
    );
    _target = incoming;
    _stale = false;
    _segment = _ScooterSegment(
      from: from,
      to: to,
      startedAt: now,
      duration: _moveDuration(previousSample, sampleTime ?? now),
    );
    _notify();
    return true;
  }

  RiderScooterPose? poseAt(DateTime now) {
    if (_disposed) {
      return _presented;
    }
    return _sample(now, commit: true);
  }

  void tick(DateTime now) {
    if (_disposed || _segment == null) {
      return;
    }
    _sample(now, commit: true);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _segment = null;
    super.dispose();
  }

  void _freeze(RiderScooterPose frozen, DateTime? sampleTime, {required bool stale}) {
    _segment = null;
    _presented = frozen;
    _target = frozen;
    _stale = stale;
    if (sampleTime != null) {
      _lastSampleTime = sampleTime;
    }
    _notify();
  }

  RiderScooterPose? _sample(DateTime now, {bool commit = false}) {
    final segment = _segment;
    if (segment == null) {
      return _presented;
    }
    final total = segment.duration.inMicroseconds;
    final elapsed = now.difference(segment.startedAt).inMicroseconds;
    final t = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final pose = RiderScooterPose(
      latitude: _lerp(segment.from.latitude, segment.to.latitude, t),
      longitude: _lerp(segment.from.longitude, segment.to.longitude, t),
      heading: _lerp(segment.from.heading, segment.to.heading, t),
    );
    if (commit) {
      _presented = pose;
      if (t >= 1) {
        _segment = null;
      }
    }
    return pose;
  }

  Duration _moveDuration(DateTime? previous, DateTime sample) {
    if (previous == null) {
      return riderScooterMinMoveDuration;
    }
    final gap = sample.difference(previous);
    if (gap < riderScooterMinMoveDuration) {
      return riderScooterMinMoveDuration;
    }
    if (gap > riderScooterMaxMoveDuration) {
      return riderScooterMaxMoveDuration;
    }
    return gap;
  }

  double _jitterHold(double? accuracyMeters) {
    if (accuracyMeters == null ||
        !accuracyMeters.isFinite ||
        accuracyMeters <= 0) {
      return riderScooterJitterMeters;
    }
    return accuracyMeters.clamp(
      riderScooterJitterMeters,
      riderScooterMaxAccuracyHoldMeters,
    );
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
      return;
    }
    notifyListeners();
  }

  static double _lerp(double from, double to, double t) => from + (to - from) * t;
}
