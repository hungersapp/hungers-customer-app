import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Navigation casing plus a solid stroke. Empty when there is no road path.
///
/// A two-point segment is rejected so a rider-to-destination straight line
/// cannot be drawn as if it were a route.
Set<Polyline> roadPolylines({
  required List<LatLng> points,
  required Color color,
  required String id,
}) {
  if (points.length < 3) {
    return const {};
  }
  return {
    Polyline(
      polylineId: PolylineId('$id-casing'),
      points: points,
      color: const Color(0xFFFFFFFF),
      width: 9,
      zIndex: 1,
      geodesic: false,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
    Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: 5,
      zIndex: 2,
      geodesic: false,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
  };
}
