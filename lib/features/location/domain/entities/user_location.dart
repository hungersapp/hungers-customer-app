import 'package:equatable/equatable.dart';

import '../../../serviceability/domain/geo_distance.dart';
import '../../../serviceability/domain/indian_pincode.dart';
import 'location_source.dart';

export 'location_source.dart';

/// Represents the authenticated user's saved delivery location.
///
/// Architecture: **one** saved location on `users/{uid}.location`.
/// Multi-address books are not supported by this model.
class UserLocation extends Equatable {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    required this.updatedAt,
    this.pincode,
    this.doorNumber = '',
    this.street = '',
    this.area = '',
    this.selectedByCustomer = false,
    this.source,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final DateTime updatedAt;
  final String? pincode;

  /// Door / house number (required for a complete checkout address).
  final String doorNumber;

  /// Street name.
  final String street;

  /// Locality / area / landmark area.
  final String area;

  /// True when this place was picked by the customer rather than read from
  /// GPS (a searched place or a saved HOME / WORK / OTHER address). On its own
  /// it does NOT make the location an explicit selection: documents saved
  /// before [source] existed carry it too, and those are legacy — see
  /// [selectionIntent].
  final bool selectedByCustomer;

  /// Where this location came from. Null only on documents written before
  /// the source was recorded (legacy).
  final LocationSource? source;

  /// Whether the customer explicitly chose this as their active location.
  ///
  ///  * [LocationSelectionIntent.explicit] — recorded as a searched / pinned
  ///    place or a saved Home / Work / Other address the customer selected.
  ///    It stays active until the customer changes it; GPS never replaces it.
  ///  * [LocationSelectionIntent.implicit] — the phone's GPS position, or a
  ///    legacy location saved before the source was recorded (whatever
  ///    address it holds). A valid GPS reading may replace it.
  LocationSelectionIntent get selectionIntent {
    return source?.isCustomerSelected ?? false
        ? LocationSelectionIntent.explicit
        : LocationSelectionIntent.implicit;
  }

  bool get isExplicitSelection =>
      selectionIntent == LocationSelectionIntent.explicit;

  /// True for a location saved before [source] was recorded that holds an
  /// address the customer once entered or picked (an old Home address that
  /// simply stayed active). It is not an explicit selection.
  bool get isLegacyAddress =>
      source == null &&
      (selectedByCustomer ||
          doorNumber.trim().isNotEmpty ||
          street.trim().isNotEmpty);

  /// True when this is the live-GPS discovery default, not a pinned search
  /// or saved address. Restaurant discovery may follow the phone; checkout
  /// still needs door / street / pincode before [placeOrder].
  bool get isLiveGpsDefault =>
      !selectedByCustomer && doorNumber.trim().isEmpty && street.trim().isEmpty;

  /// City, state, and optional pincode for compact UI.
  String get displayAddress {
    final pin = pincode?.trim();
    if (pin != null && pin.isNotEmpty) {
      return '$city, $state · $pin';
    }
    return '$city, $state';
  }

  /// Human-readable line used on orders (`deliveryAddress.address`).
  String get detailedAddressLine {
    final parts = <String>[
      doorNumber.trim(),
      street.trim(),
      area.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(', ');
  }

  /// Multi-line checkout / profile summary (no lat/lng).
  String get checkoutDisplayBlock {
    final lines = <String>[];
    final detail = detailedAddressLine;
    if (detail.isNotEmpty) {
      lines.add(detail);
    }
    final cityLine = [
      if (area.trim().isNotEmpty && !detail.contains(area.trim())) area.trim(),
      city.trim(),
    ].where((p) => p.isNotEmpty).join(', ');
    final pin = pincode?.trim();
    if (cityLine.isNotEmpty || (pin != null && pin.isNotEmpty)) {
      lines.add(
        [
          if (cityLine.isNotEmpty) cityLine,
          if (pin != null && pin.isNotEmpty) pin,
        ].join(' - '),
      );
    } else if (displayAddress.isNotEmpty) {
      lines.add(displayAddress);
    }
    return lines.join('\n');
  }

  /// Complete enough to browse restaurants for: usable coordinates (in range,
  /// not the (0,0) placeholder) and a city and state to show. The coordinates
  /// are what serviceability and discovery are decided from; a pincode is only
  /// address metadata and is not needed. Door and street are only needed to
  /// place an order ([isCompleteForCheckout]).
  bool get isCompleteForDiscovery {
    if (!GeoDistance.isValidLatitude(latitude) ||
        !GeoDistance.isValidLongitude(longitude) ||
        (latitude == 0 && longitude == 0)) {
      return false;
    }
    return city.trim().isNotEmpty && state.trim().isNotEmpty;
  }

  /// Complete enough to place a COD order with distance-based delivery fee.
  bool get isCompleteForCheckout {
    if (!GeoDistance.isValidLatitude(latitude) ||
        !GeoDistance.isValidLongitude(longitude)) {
      return false;
    }
    if (doorNumber.trim().isEmpty || street.trim().isEmpty) {
      return false;
    }
    if (city.trim().isEmpty || state.trim().isEmpty) {
      return false;
    }
    final pin = pincode?.trim() ?? '';
    return IndianPincode.isValid(pin);
  }

  UserLocation copyWith({
    double? latitude,
    double? longitude,
    String? city,
    String? state,
    DateTime? updatedAt,
    String? pincode,
    String? doorNumber,
    String? street,
    String? area,
    bool? selectedByCustomer,
    LocationSource? source,
    bool clearPincode = false,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      pincode: clearPincode ? null : (pincode ?? this.pincode),
      doorNumber: doorNumber ?? this.doorNumber,
      street: street ?? this.street,
      area: area ?? this.area,
      selectedByCustomer: selectedByCustomer ?? this.selectedByCustomer,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    city,
    state,
    updatedAt,
    pincode,
    doorNumber,
    street,
    area,
    selectedByCustomer,
    source,
  ];
}
