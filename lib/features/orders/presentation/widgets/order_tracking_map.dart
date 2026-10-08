import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/location/google_directions_route.dart';
import '../../../../core/location/rider_scooter_motion.dart';
import '../../../../core/location/road_polylines.dart';
import '../../../../core/location/road_route_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/order_tracking_map_plan.dart';
import '../rider_marker_visual.dart';
import 'rider_marker_icon_factory.dart';

/// Renders restaurant / customer / rider pins from [OrderTrackingMapPlan].
///
/// The [GoogleMap] is created once for a given restaurant/customer pair.
/// The bunny marker glides between accepted GPS fixes. The polyline is a
/// separate driving route and is not used to move the marker. The camera
/// is never moved from here.
class OrderTrackingMap extends StatefulWidget {
  const OrderTrackingMap({
    super.key,
    required this.plan,
  });

  final OrderTrackingMapPlan plan;

  static const double height = 220;
  static const double defaultZoom = 14;

  @override
  State<OrderTrackingMap> createState() => _OrderTrackingMapState();
}

class _OrderTrackingMapState extends State<OrderTrackingMap>
    with SingleTickerProviderStateMixin {
  BitmapDescriptor? _riderIcon;
  bool _iconLoadStarted = false;
  final RiderMarkerVisual _riderVisual = RiderMarkerVisual();
  final RiderScooterMotion _motion = RiderScooterMotion();
  final RoadRouteSession _roadRoute = RoadRouteSession();
  late final Ticker _ticker;

  double? _appliedLat;
  double? _appliedLng;
  DateTime? _appliedAt;
  bool? _appliedFresh;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _motion.tick(DateTime.now()));
    _motion.addListener(_onMotion);
    _loadRiderIcon();
    _publishRider();
    _requestRoadRoute();
  }

  @override
  void didUpdateWidget(OrderTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publishRider();
    _requestRoadRoute();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.removeListener(_onMotion);
    _motion.dispose();
    _roadRoute.dispose();
    super.dispose();
  }

  void _onMotion() {
    if (!mounted) {
      return;
    }
    if (_motion.isAnimating) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _publishRider() {
    final rider = widget.plan.rider;
    final fresh = widget.plan.riderLocationFresh;
    final updatedAt = widget.plan.riderUpdatedAt;
    if (rider == null) {
      if (_appliedLat != null) {
        _riderVisual.reset();
        _appliedLat = null;
        _appliedLng = null;
        _appliedAt = null;
        _appliedFresh = null;
        _motion.offer(
          latitude: 0,
          longitude: 0,
          heading: 0,
          now: DateTime.now(),
          stopped: true,
        );
      }
      return;
    }
    if (_appliedLat == rider.latitude &&
        _appliedLng == rider.longitude &&
        _appliedAt == updatedAt &&
        _appliedFresh == fresh) {
      return;
    }
    if (updatedAt != null &&
        _appliedAt != null &&
        updatedAt.isBefore(_appliedAt!)) {
      return;
    }
    _appliedLat = rider.latitude;
    _appliedLng = rider.longitude;
    _appliedAt = updatedAt;
    _appliedFresh = fresh;
    _riderVisual.apply(
      latitude: rider.latitude,
      longitude: rider.longitude,
    );
    final latitude = _riderVisual.displayLatitude ?? rider.latitude;
    final longitude = _riderVisual.displayLongitude ?? rider.longitude;
    _motion.offer(
      latitude: latitude,
      longitude: longitude,
      heading: _riderVisual.heading,
      now: DateTime.now(),
      sampleTime: updatedAt,
      stale: !fresh,
    );
    _onMotion();
  }

  void _requestRoadRoute() {
    final endpoints = trackingRoadEndpoints(widget.plan);
    unawaited(
      _roadRoute.update(
        origin: endpoints.origin,
        destination: endpoints.destination,
        fetch: fetchDrivingRoute,
      ),
    );
  }

  Future<void> _loadRiderIcon() async {
    if (_iconLoadStarted) {
      return;
    }
    _iconLoadStarted = true;
    final icon = await RiderMarkerIconFactory.build();
    if (!mounted) {
      return;
    }
    setState(() => _riderIcon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    if (plan.isEmpty) {
      return const SizedBox.shrink();
    }

    final cameraTarget = _cameraTarget(plan);
    if (cameraTarget == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: OrderTrackingMap.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_motion, _roadRoute]),
          builder: (context, _) {
            return GoogleMap(
              key: ValueKey(
                'tracking-${plan.restaurant?.latitude}-'
                '${plan.restaurant?.longitude}-'
                '${plan.customer?.latitude}-'
                '${plan.customer?.longitude}',
              ),
              initialCameraPosition: CameraPosition(
                target: cameraTarget,
                zoom: OrderTrackingMap.defaultZoom,
              ),
              markers: _markers(plan),
              polylines: roadPolylines(
                points: _roadRoute.points,
                color: AppColors.primary,
                id: 'tracking-route',
              ),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: false,
            );
          },
        ),
      ),
    );
  }

  Set<Marker> _markers(OrderTrackingMapPlan plan) {
    final markers = <Marker>{};
    if (plan.restaurant != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: LatLng(
            plan.restaurant!.latitude,
            plan.restaurant!.longitude,
          ),
          infoWindow: InfoWindow(title: plan.restaurant!.label),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }
    if (plan.customer != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(
            plan.customer!.latitude,
            plan.customer!.longitude,
          ),
          infoWindow: InfoWindow(title: plan.customer!.label),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    final pose = _motion.pose;
    if (plan.rider != null && pose != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(pose.latitude, pose.longitude),
          rotation: pose.heading,
          infoWindow: InfoWindow(title: plan.rider!.label),
          icon:
              _riderIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
          anchor: RiderMarkerIconFactory.anchor,
          flat: true,
          zIndexInt: 2,
        ),
      );
    }
    return markers;
  }

  /// Restaurant (or customer) is the initial camera — never the moving
  /// rider — so live GPS cannot steal pan/zoom.
  static LatLng? _cameraTarget(OrderTrackingMapPlan plan) {
    final point = plan.restaurant ?? plan.customer ?? plan.rider;
    if (point == null) {
      return null;
    }
    return LatLng(point.latitude, point.longitude);
  }
}

/// Origin and destination for the driving route. The rider marker is not
/// an endpoint of the restaurant-to-customer leg.
class TrackingRoadEndpoints {
  const TrackingRoadEndpoints({this.origin, this.destination});

  final LatLng? origin;
  final LatLng? destination;
}

TrackingRoadEndpoints trackingRoadEndpoints(OrderTrackingMapPlan plan) {
  switch (plan.routeKind) {
    case OrderTrackingRouteKind.riderToRestaurant:
      final rider = plan.rider;
      final restaurant = plan.restaurant;
      if (rider == null || restaurant == null) {
        return const TrackingRoadEndpoints();
      }
      return TrackingRoadEndpoints(
        origin: LatLng(rider.latitude, rider.longitude),
        destination: LatLng(restaurant.latitude, restaurant.longitude),
      );
    case OrderTrackingRouteKind.restaurantToCustomer:
      final restaurant = plan.restaurant;
      final customer = plan.customer;
      if (restaurant == null || customer == null) {
        return const TrackingRoadEndpoints();
      }
      return TrackingRoadEndpoints(
        origin: LatLng(restaurant.latitude, restaurant.longitude),
        destination: LatLng(customer.latitude, customer.longitude),
      );
    case OrderTrackingRouteKind.none:
      return const TrackingRoadEndpoints();
  }
}
