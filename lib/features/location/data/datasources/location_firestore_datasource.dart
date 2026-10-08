import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_location_model.dart';

class LocationFirestoreDatasource {
  const LocationFirestoreDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  /// Writes `users/{uid}.location` — the customer's ACTIVE location.
  ///
  /// This document field is authoritative for restaurant discovery and
  /// ordering, so it has exactly two legitimate writers, both owned by
  /// `LocationSetupNotifier`: the customer explicitly selecting a place, and
  /// a device GPS reading applied under `LocationRefreshPolicy`.
  ///
  /// [clearStaleAddressDetails] must be set whenever the new [location] is a
  /// different place from what is stored, so the previous pincode / door /
  /// street / area (and the top-level `deliveryPincode` fallback) cannot
  /// survive the merge and be mixed with the new coordinates.
  Future<void> saveLocation({
    required String userId,
    required UserLocationModel location,
    bool clearStaleAddressDetails = false,
  }) async {
    await _userDoc(userId).set({
      'location': location.toMap(
        clearStaleAddressDetails: clearStaleAddressDetails,
      ),
      if (location.pincode != null)
        'deliveryPincode': location.pincode
      else if (clearStaleAddressDetails)
        'deliveryPincode': null,
    }, SetOptions(merge: true));
  }

  Future<UserLocationModel?> getLocation(String userId) async {
    final snapshot = await _userDoc(userId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    final locationData = data?['location'];
    final fallbackPincode = _readPincode(data?['deliveryPincode']);

    if (locationData is! Map<String, dynamic>) {
      return null;
    }

    if (locationData['latitude'] is! num || locationData['longitude'] is! num) {
      return null;
    }

    return UserLocationModel.fromMap(
      locationData,
      fallbackPincode: fallbackPincode,
    );
  }

  Future<String?> getDeliveryPincode(String userId) async {
    final snapshot = await _userDoc(userId).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    final locationData = data?['location'];
    if (locationData is Map<String, dynamic>) {
      final fromLocation = _readPincode(locationData['pincode']);
      if (fromLocation != null) {
        return fromLocation;
      }
    }
    return _readPincode(data?['deliveryPincode']);
  }

  Future<void> saveDeliveryPincode({
    required String userId,
    required String pincode,
  }) async {
    await _userDoc(userId).set({
      'deliveryPincode': pincode,
      'location': {'pincode': pincode},
    }, SetOptions(merge: true));
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

  Future<Map<String, dynamic>> _readSavedAddressesMap(String userId) async {
    final snapshot = await _userDoc(userId).get();
    final data = snapshot.data();
    final raw = data?['savedAddresses'];
    if (raw is! Map) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<UserLocationModel?> getSavedAddress({
    required String userId,
    required String slot,
  }) async {
    final map = await _readSavedAddressesMap(userId);
    final raw = map[slot];
    if (raw is! Map) {
      return null;
    }
    final locationData = Map<String, dynamic>.from(raw);
    if (locationData['latitude'] is! num || locationData['longitude'] is! num) {
      return null;
    }
    return UserLocationModel.fromMap(locationData);
  }

  Future<Map<String, UserLocationModel>> getSavedAddresses(
    String userId,
  ) async {
    final map = await _readSavedAddressesMap(userId);
    final result = <String, UserLocationModel>{};
    for (final entry in map.entries) {
      final raw = entry.value;
      if (raw is! Map) {
        continue;
      }
      final locationData = Map<String, dynamic>.from(raw);
      if (locationData['latitude'] is! num ||
          locationData['longitude'] is! num) {
        continue;
      }
      result[entry.key] = UserLocationModel.fromMap(locationData);
    }
    return result;
  }

  Future<void> saveSavedAddress({
    required String userId,
    required String slot,
    required UserLocationModel location,
  }) async {
    await _userDoc(userId).set({
      'savedAddresses': {slot: location.toMap(clearStaleAddressDetails: true)},
    }, SetOptions(merge: true));
  }

  Future<void> deleteSavedAddress({
    required String userId,
    required String slot,
  }) async {
    await _userDoc(userId).set({
      'savedAddresses': {slot: FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  /// `users/{uid}.recentLocationSearches`: places the customer searched for
  /// and selected, newest first. A shortcut list only — never the active
  /// location.
  Future<List<UserLocationModel>> getRecentSearches(String userId) async {
    final snapshot = await _userDoc(userId).get();
    final raw = snapshot.data()?['recentLocationSearches'];
    if (raw is! List) {
      return const [];
    }
    final result = <UserLocationModel>[];
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final data = Map<String, dynamic>.from(entry);
      if (data['latitude'] is! num || data['longitude'] is! num) {
        continue;
      }
      result.add(UserLocationModel.fromMap(data));
    }
    return result;
  }

  Future<void> saveRecentSearches({
    required String userId,
    required List<UserLocationModel> locations,
  }) async {
    await _userDoc(userId).set({
      'recentLocationSearches': [
        for (final location in locations)
          location.toMap(clearStaleAddressDetails: true),
      ],
    }, SetOptions(merge: true));
  }
}
