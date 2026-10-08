import 'package:equatable/equatable.dart';

import '../zone_polygon.dart';

/// Boundary contract from existing `serviceability_zones` documents.
/// Not a Super Admin zone CRUD model.
///
/// A zone is its centre + [radiusKm] circle unless [usesPolygon] is true
/// (`serviceabilityMethod == CUSTOM_POLYGON`), in which case [polygon]
/// alone decides and the radius is never consulted.
class ActiveDeliveryZone extends Equatable {
  const ActiveDeliveryZone({
    required this.id,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.isActive,
    this.usesPolygon = false,
    this.polygon = const [],
  });

  final String id;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;
  final bool isActive;
  final bool usesPolygon;
  final List<ZonePoint> polygon;

  @override
  List<Object?> get props => [
        id,
        centerLatitude,
        centerLongitude,
        radiusKm,
        isActive,
        usesPolygon,
        polygon,
      ];
}
