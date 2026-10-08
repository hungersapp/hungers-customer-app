import '../../domain/entities/rider_location.dart';
import '../../../serviceability/domain/geo_distance.dart';

class RiderLocationModel {
  RiderLocationModel._();

  static DeliveryJobRiderTracking? fromJobDocument(
    String orderId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) {
      return null;
    }
    final status = _readString(data['status']);
    if (status.isEmpty) {
      return null;
    }
    return DeliveryJobRiderTracking(
      orderId: orderId,
      status: status,
      riderLocation: parseRiderLocation(data['riderLocation']),
      riderPhone: _readNullablePhone(data['riderPhone']),
      riderDisplayName: _readNullableText(data['riderDisplayName']),
      riderRating: _readDouble(data['riderRating']),
      riderPhotoUrl: _readHttpsUrl(data['riderPhotoUrl']),
    );
  }

  static String? _readNullablePhone(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _readNullableText(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _readHttpsUrl(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (!trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed;
  }

  static RiderLocation? parseRiderLocation(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final latitude = _readDouble(map['latitude']);
    final longitude = _readDouble(map['longitude']);
    final updatedAt = _readDate(map['updatedAt']);
    if (latitude == null || longitude == null || updatedAt == null) {
      return null;
    }
    if (!GeoDistance.isValidLatitude(latitude) ||
        !GeoDistance.isValidLongitude(longitude)) {
      return null;
    }
    if (latitude == 0 && longitude == 0) {
      return null;
    }
    return RiderLocation(
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String _readString(Object? value) {
    return value is String ? value.trim() : '';
  }

  static DateTime? _readDate(Object? raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    try {
      final timestamp = raw as dynamic;
      return timestamp.toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}
