import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_directions_route.dart';

/// Holds one driving-route polyline and refetches only when the trip
/// actually changes.
///
/// Origin drift under [refetchOriginMeters] keeps the current road path.
/// That stops a GPS tick from requesting a new route on every fix. The
/// bunny still moves from live GPS; this session never moves the marker.
class RoadRouteSession extends ChangeNotifier {
  RoadRouteSession({this.refetchOriginMeters = 180});

  final double refetchOriginMeters;

  List<LatLng> points = const [];
  int? distanceMeters;
  LatLng? _fetchedOrigin;
  LatLng? _fetchedDestination;
  int _generation = 0;

  Future<void> update({
    required LatLng? origin,
    required LatLng? destination,
    required Future<DrivingRoute> Function(LatLng origin, LatLng destination)
    fetch,
  }) async {
    if (origin == null || destination == null) {
      _generation++;
      _clear();
      return;
    }
    if (_matchesCurrent(origin, destination)) {
      return;
    }
    final generation = ++_generation;
    final next = await fetch(origin, destination);
    if (generation != _generation) {
      return;
    }
    if (next.points.length < 2) {
      return;
    }
    points = List<LatLng>.unmodifiable(next.points);
    distanceMeters = next.distanceMeters;
    _fetchedOrigin = origin;
    _fetchedDestination = destination;
    notifyListeners();
  }

  bool _matchesCurrent(LatLng origin, LatLng destination) {
    final fetchedOrigin = _fetchedOrigin;
    final fetchedDestination = _fetchedDestination;
    if (fetchedOrigin == null ||
        fetchedDestination == null ||
        points.length < 2) {
      return false;
    }
    return _meters(origin, fetchedOrigin) < refetchOriginMeters &&
        _meters(destination, fetchedDestination) < 40;
  }

  void _clear() {
    if (points.isEmpty &&
        _fetchedOrigin == null &&
        _fetchedDestination == null) {
      return;
    }
    points = const [];
    distanceMeters = null;
    _fetchedOrigin = null;
    _fetchedDestination = null;
    notifyListeners();
  }

  static double _meters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
  }
}
