import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/active_delivery_zone.dart';
import '../../domain/zone_polygon.dart';

/// Reads existing `serviceability_zones` documents.
///
/// The query must constrain `isActive == true` so it matches the
/// authenticated Customer read rule. Failures stay fail-closed.
class ServiceabilityZonesFirestoreDatasource {
  ServiceabilityZonesFirestoreDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<ActiveDeliveryZone>> getActiveDeliveryZones() async {
    final snapshot = await _firestore
        .collection('serviceability_zones')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final latitude = data['centerLatitude'];
          final longitude = data['centerLongitude'];
          final radius = data['radiusKm'];
          // A Custom Polygon zone is decided by its polygon alone, so it
          // does not need a radius to be usable.
          final usesPolygon = data['serviceabilityMethod'] == 'CUSTOM_POLYGON';
          if (latitude is! num ||
              longitude is! num ||
              (radius is! num && !usesPolygon)) {
            return null;
          }
          return ActiveDeliveryZone(
            id: doc.id,
            centerLatitude: latitude.toDouble(),
            centerLongitude: longitude.toDouble(),
            radiusKm: radius is num ? radius.toDouble() : 0,
            isActive: data['isActive'] == true,
            usesPolygon: usesPolygon,
            polygon: usesPolygon
                ? ZonePoint.listFrom(data['customPolygon'])
                : const [],
          );
        })
        .whereType<ActiveDeliveryZone>()
        .where((zone) => zone.isActive)
        .toList();
  }
}
