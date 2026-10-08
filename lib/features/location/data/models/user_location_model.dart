import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_location.dart';

class UserLocationModel extends UserLocation {
  const UserLocationModel({
    required super.latitude,
    required super.longitude,
    required super.city,
    required super.state,
    required super.updatedAt,
    super.pincode,
    super.doorNumber,
    super.street,
    super.area,
    super.selectedByCustomer,
    super.source,
  });

  factory UserLocationModel.fromMap(
    Map<String, dynamic> map, {
    String? fallbackPincode,
  }) {
    return UserLocationModel(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      city: _readString(map['city']),
      state: _readString(map['state']),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      pincode: _readPincode(map['pincode']) ?? fallbackPincode,
      doorNumber: _readString(
        map['doorNumber'] ?? map['door'] ?? map['houseNumber'],
      ),
      street: _readString(map['street']),
      area: _readString(map['area'] ?? map['locality']),
      selectedByCustomer: map['selectedByCustomer'] == true,
      source: LocationSource.fromFirestore(map['source']),
    );
  }

  /// Firestore map for `users/{uid}.location`.
  ///
  /// The write is a `SetOptions(merge: true)` merge, and a merge keeps every
  /// key the payload omits. So by default the optional address fields
  /// (`pincode`, `doorNumber`, `street`, `area`) are omitted when blank —
  /// which is right for a partial update such as a typed pincode, but WRONG
  /// when the location itself is being replaced by a different place: the old
  /// place's pincode / door / street / area would silently stay attached to
  /// the new coordinates.
  ///
  /// [clearStaleAddressDetails] makes a replacement coherent: every optional
  /// field is written explicitly (an explicit `null` pincode, blank strings for
  /// the rest), so nothing from the previous location survives the merge.
  Map<String, dynamic> toMap({bool clearStaleAddressDetails = false}) {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'state': state,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (pincode != null || clearStaleAddressDetails) 'pincode': pincode,
      if (doorNumber.trim().isNotEmpty || clearStaleAddressDetails)
        'doorNumber': doorNumber.trim(),
      if (street.trim().isNotEmpty || clearStaleAddressDetails)
        'street': street.trim(),
      if (area.trim().isNotEmpty || clearStaleAddressDetails)
        'area': area.trim(),
      // Written when true, and explicitly on a full replacement, so a place
      // chosen by the customer is never left flagged as a GPS default (or the
      // reverse) by a merge.
      if (selectedByCustomer || clearStaleAddressDetails)
        'selectedByCustomer': selectedByCustomer,
      // Same rule for where the location came from: a full replacement
      // writes it explicitly, so a GPS reading never inherits the previous
      // selection's source (and with it, its explicit intent).
      if (source != null || clearStaleAddressDetails)
        'source': source?.firestoreValue,
    };
  }

  factory UserLocationModel.fromEntity(UserLocation location) {
    return UserLocationModel(
      latitude: location.latitude,
      longitude: location.longitude,
      city: location.city,
      state: location.state,
      updatedAt: location.updatedAt,
      pincode: location.pincode,
      doorNumber: location.doorNumber,
      street: location.street,
      area: location.area,
      selectedByCustomer: location.selectedByCustomer,
      source: location.source,
    );
  }

  static String _readString(Object? value) {
    if (value is! String) {
      return '';
    }
    return value.trim();
  }

  static String? _readPincode(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }
}
