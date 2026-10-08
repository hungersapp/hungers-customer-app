import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'encoded_polyline.dart';

/// Existing Maps SDK key plus the Android package and signing certificate.
///
/// The key stays in the Android manifest. It is never written into Dart
/// source, logs, or this object's default string form.
class MapsApiCredentials {
  const MapsApiCredentials({
    required this.apiKey,
    required this.packageName,
    required this.sha1,
  });

  final String apiKey;
  final String packageName;
  final String sha1;

  static const MethodChannel channel = MethodChannel('tukkito/maps_credentials');

  static Future<MapsApiCredentials?> read() async {
    try {
      final raw = await channel.invokeMapMethod<String, String>('get');
      if (raw == null) {
        return null;
      }
      final apiKey = raw['apiKey'] ?? '';
      if (apiKey.isEmpty) {
        return null;
      }
      return MapsApiCredentials(
        apiKey: apiKey,
        packageName: raw['packageName'] ?? '',
        sha1: raw['sha1'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'MapsApiCredentials(packageName: $packageName)';
}

class DirectionsParse {
  const DirectionsParse({
    required this.status,
    required this.points,
    this.distanceMeters,
    this.errorMessage,
  });

  final String status;
  final String? errorMessage;
  final List<LatLng> points;

  /// `routes[0].legs[0].distance.value` from the Directions response.
  final int? distanceMeters;

  bool get isRoadRoute => status == 'OK' && points.length >= 2;
}

class DrivingRoute {
  const DrivingRoute({required this.points, this.distanceMeters});

  final List<LatLng> points;
  final int? distanceMeters;

  static const empty = DrivingRoute(points: []);
}

/// Reads `routes[0].overview_polyline.points` from a Directions JSON body.
DirectionsParse parseDirectionsBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    return const DirectionsParse(status: 'INVALID', points: []);
  }
  final status = decoded['status']?.toString() ?? 'INVALID';
  final errorMessage = decoded['error_message']?.toString();
  if (status != 'OK') {
    return DirectionsParse(
      status: status,
      errorMessage: errorMessage,
      points: const [],
    );
  }
  final routes = decoded['routes'];
  if (routes is! List || routes.isEmpty || routes.first is! Map) {
    return DirectionsParse(status: status, points: const []);
  }
  final route = routes.first as Map;
  final overview = route['overview_polyline'];
  final encoded = overview is Map ? overview['points']?.toString() : null;
  if (encoded == null || encoded.isEmpty) {
    return DirectionsParse(status: status, points: const []);
  }
  return DirectionsParse(
    status: status,
    points: decodeEncodedPolyline(encoded),
    distanceMeters: _legDistanceMeters(route),
  );
}

int? _legDistanceMeters(Map route) {
  final legs = route['legs'];
  if (legs is! List || legs.isEmpty || legs.first is! Map) {
    return null;
  }
  final distance = (legs.first as Map)['distance'];
  final value = distance is Map ? distance['value'] : null;
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

/// Driving route from the Directions API using the existing Maps SDK key.
///
/// An Android-restricted key is sent with `X-Android-Package` and
/// `X-Android-Cert` so the request is the same app the key already allows
/// for map tiles. Returns an empty list when the call cannot produce a
/// road path. Callers must not invent a straight line in that case.
Future<DrivingRoute> fetchDrivingRoute(
  LatLng origin,
  LatLng destination,
) async {
  final credentials = await MapsApiCredentials.read();
  if (credentials == null) {
    debugPrint('road_route credentials_unavailable');
    return DrivingRoute.empty;
  }
  final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
    'origin': '${origin.latitude},${origin.longitude}',
    'destination': '${destination.latitude},${destination.longitude}',
    'mode': 'driving',
    'key': credentials.apiKey,
  });
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    if (credentials.packageName.isNotEmpty && credentials.sha1.isNotEmpty) {
      request.headers.set('X-Android-Package', credentials.packageName);
      request.headers.set('X-Android-Cert', credentials.sha1);
    }
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();
    final parsed = parseDirectionsBody(body);
    if (!parsed.isRoadRoute) {
      debugPrint(
        'road_route status=${parsed.status} '
        'http=${response.statusCode} '
        'detail=${parsed.errorMessage ?? ''}',
      );
      return DrivingRoute.empty;
    }
    return DrivingRoute(
      points: parsed.points,
      distanceMeters: parsed.distanceMeters,
    );
  } catch (_) {
    debugPrint('road_route request_failed');
    return DrivingRoute.empty;
  } finally {
    client.close(force: true);
  }
}
