import '../../../core/geo/geohash.dart';
import '../../location/domain/discovery_location_kind.dart';
import '../../location/domain/entities/saved_address_book.dart';
import '../../location/domain/entities/user_location.dart';
import '../../serviceability/domain/geo_distance.dart';
import 'entities/restaurant_entity.dart';
import 'restaurant_customer_visibility.dart';
import 'restaurant_delivery_range.dart';
import 'restaurant_discovery_query.dart';

/// First pipeline stage that yields an empty restaurant list.
enum DiscoveryEmptyStage {
  noDestination,
  notServiceable,
  noGeohashCells,
  firestoreGeohashQueryEmpty,
  visibilityOrOpenFilter,
  listableFilter,
  invalidRestaurantCoordinates,
  outside15km,
  none,
}

/// Read-only probe of a `restaurant_public` document (or a test stand-in).
class RestaurantPublicProbe {
  const RestaurantPublicProbe({
    required this.restaurantId,
    required this.latitude,
    required this.longitude,
    this.geohash,
    this.geohash4,
    this.isCustomerVisible = true,
    this.isOpen = true,
    this.isActive = true,
    this.isVerified = true,
    this.onboardingStatus = 'approved',
    this.approvedFoodCount = 1,
  });

  final String restaurantId;
  final double latitude;
  final double longitude;
  final String? geohash;
  final String? geohash4;
  final bool isCustomerVisible;
  final bool isOpen;
  final bool isActive;
  final bool isVerified;
  final String onboardingStatus;
  final int approvedFoodCount;

  bool get hasGeohash4 => (geohash4 ?? '').trim().isNotEmpty;

  String get computedGeohash4 => GeoHash.cell4(latitude, longitude);

  bool get isListable => RestaurantCustomerVisibility.isCustomerListable(
    onboardingStatus: onboardingStatus,
    isVerified: isVerified,
    isCustomerVisible: isCustomerVisible,
    isActive: isActive,
    isOpen: isOpen,
    approvedFoodCount: approvedFoodCount,
  );
}

/// Explains why discovery is empty without changing query behaviour.
class DiscoveryDiagnosticReport {
  const DiscoveryDiagnosticReport({
    required this.latitude,
    required this.longitude,
    required this.locationKind,
    required this.selectedByCustomer,
    required this.isLiveGpsDefault,
    required this.serviceable,
    required this.geohash4Cells,
    required this.queryCountByCell,
    required this.rawDocumentsReturned,
    required this.removedNotVisible,
    required this.removedNotOpen,
    required this.removedNotListable,
    required this.removedInvalidCoordinates,
    required this.removedOutside15km,
    required this.finalCount,
    required this.firstEmptyStage,
    this.missingGeohash4Message,
    this.knownRestaurant,
  });

  final double latitude;
  final double longitude;
  final DiscoveryLocationKind locationKind;
  final bool selectedByCustomer;
  final bool isLiveGpsDefault;
  final bool serviceable;
  final List<String> geohash4Cells;
  final Map<String, int> queryCountByCell;
  final int rawDocumentsReturned;
  final int removedNotVisible;
  final int removedNotOpen;
  final int removedNotListable;
  final int removedInvalidCoordinates;
  final int removedOutside15km;
  final int finalCount;
  final DiscoveryEmptyStage firstEmptyStage;
  final String? missingGeohash4Message;
  final KnownRestaurantDiagnostic? knownRestaurant;

  String get firstEmptyStageLabel {
    switch (firstEmptyStage) {
      case DiscoveryEmptyStage.noDestination:
        return 'no destination';
      case DiscoveryEmptyStage.notServiceable:
        return 'serviceability (outside active zones)';
      case DiscoveryEmptyStage.noGeohashCells:
        return 'geohash cell generation';
      case DiscoveryEmptyStage.firestoreGeohashQueryEmpty:
        return 'Firestore geohash4 equality query';
      case DiscoveryEmptyStage.visibilityOrOpenFilter:
        return 'isCustomerVisible / isOpen query filter';
      case DiscoveryEmptyStage.listableFilter:
        return 'isCustomerListable (active/verified/menu)';
      case DiscoveryEmptyStage.invalidRestaurantCoordinates:
        return 'missing/invalid restaurant coordinates';
      case DiscoveryEmptyStage.outside15km:
        return 'Haversine 15 km filter';
      case DiscoveryEmptyStage.none:
        return 'none (restaurants remain)';
    }
  }
}

class KnownRestaurantDiagnostic {
  const KnownRestaurantDiagnostic({
    required this.restaurantId,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.geohash4,
    required this.computedGeohash4,
    required this.isCustomerVisible,
    required this.isOpen,
    required this.isListable,
    required this.geohash4InCustomerCells,
    required this.computedGeohash4InCustomerCells,
    required this.distanceKm,
    required this.wouldPass15km,
    required this.missingGeohash4,
  });

  final String restaurantId;
  final double latitude;
  final double longitude;
  final String? geohash;
  final String? geohash4;
  final String computedGeohash4;
  final bool isCustomerVisible;
  final bool isOpen;
  final bool isListable;
  final bool geohash4InCustomerCells;
  final bool computedGeohash4InCustomerCells;
  final double? distanceKm;
  final bool wouldPass15km;
  final bool missingGeohash4;
}

/// Simulates the production discovery pipeline in memory.
///
/// Firestore `where('geohash4', isEqualTo: cell)` never returns documents
/// whose `geohash4` field is missing — that is stage
/// [DiscoveryEmptyStage.firestoreGeohashQueryEmpty].
class DiscoveryDiagnostic {
  DiscoveryDiagnostic._();

  static DiscoveryDiagnosticReport analyze({
    required UserLocation? destination,
    required bool serviceable,
    required List<RestaurantPublicProbe> catalog,
    SavedAddressBook? book,
  }) {
    if (destination == null) {
      return const DiscoveryDiagnosticReport(
        latitude: 0,
        longitude: 0,
        locationKind: DiscoveryLocationKind.currentLocation,
        selectedByCustomer: false,
        isLiveGpsDefault: false,
        serviceable: false,
        geohash4Cells: [],
        queryCountByCell: {},
        rawDocumentsReturned: 0,
        removedNotVisible: 0,
        removedNotOpen: 0,
        removedNotListable: 0,
        removedInvalidCoordinates: 0,
        removedOutside15km: 0,
        finalCount: 0,
        firstEmptyStage: DiscoveryEmptyStage.noDestination,
      );
    }

    final presentation = DiscoveryLocationPresentation.from(
      location: destination,
      book: book,
    );
    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination);
    final cellSet = cells.toSet();

    if (!serviceable) {
      return DiscoveryDiagnosticReport(
        latitude: destination.latitude,
        longitude: destination.longitude,
        locationKind: presentation.kind,
        selectedByCustomer: destination.selectedByCustomer,
        isLiveGpsDefault: destination.isLiveGpsDefault,
        serviceable: false,
        geohash4Cells: cells,
        queryCountByCell: const {},
        rawDocumentsReturned: 0,
        removedNotVisible: 0,
        removedNotOpen: 0,
        removedNotListable: 0,
        removedInvalidCoordinates: 0,
        removedOutside15km: 0,
        finalCount: 0,
        firstEmptyStage: DiscoveryEmptyStage.notServiceable,
      );
    }

    if (cells.isEmpty) {
      return DiscoveryDiagnosticReport(
        latitude: destination.latitude,
        longitude: destination.longitude,
        locationKind: presentation.kind,
        selectedByCustomer: destination.selectedByCustomer,
        isLiveGpsDefault: destination.isLiveGpsDefault,
        serviceable: true,
        geohash4Cells: cells,
        queryCountByCell: const {},
        rawDocumentsReturned: 0,
        removedNotVisible: 0,
        removedNotOpen: 0,
        removedNotListable: 0,
        removedInvalidCoordinates: 0,
        removedOutside15km: 0,
        finalCount: 0,
        firstEmptyStage: DiscoveryEmptyStage.noGeohashCells,
      );
    }

    final queryCountByCell = <String, int>{
      for (final cell in cells) cell: 0,
    };
    final matched = <RestaurantPublicProbe>[];
    var missingGeohash4Nearby = 0;
    for (final restaurant in catalog) {
      final stored = restaurant.geohash4?.trim() ?? '';
      if (stored.isEmpty) {
        final computedInCovering = cellSet.contains(restaurant.computedGeohash4);
        final km = GeoDistance.calculateDistanceKm(
          latitude1: destination.latitude,
          longitude1: destination.longitude,
          latitude2: restaurant.latitude,
          longitude2: restaurant.longitude,
        );
        if (computedInCovering && km != null && km <= RestaurantDeliveryRange.maxDistanceKm) {
          missingGeohash4Nearby += 1;
        }
        continue;
      }
      if (!cellSet.contains(stored)) {
        continue;
      }
      queryCountByCell[stored] = (queryCountByCell[stored] ?? 0) + 1;
      matched.add(restaurant);
    }

    final raw = matched.length;
    String? missingMessage;
    if (raw == 0 && missingGeohash4Nearby > 0) {
      missingMessage =
          'Restaurant excluded because geohash4 is missing; production backfill required.';
    }

    if (raw == 0) {
      return DiscoveryDiagnosticReport(
        latitude: destination.latitude,
        longitude: destination.longitude,
        locationKind: presentation.kind,
        selectedByCustomer: destination.selectedByCustomer,
        isLiveGpsDefault: destination.isLiveGpsDefault,
        serviceable: true,
        geohash4Cells: cells,
        queryCountByCell: queryCountByCell,
        rawDocumentsReturned: 0,
        removedNotVisible: 0,
        removedNotOpen: 0,
        removedNotListable: 0,
        removedInvalidCoordinates: 0,
        removedOutside15km: 0,
        finalCount: 0,
        firstEmptyStage: DiscoveryEmptyStage.firestoreGeohashQueryEmpty,
        missingGeohash4Message: missingMessage,
      );
    }

    var removedNotVisible = 0;
    var removedNotOpen = 0;
    final afterQueryFilters = <RestaurantPublicProbe>[];
    for (final restaurant in matched) {
      if (!restaurant.isCustomerVisible) {
        removedNotVisible += 1;
        continue;
      }
      if (!restaurant.isOpen) {
        removedNotOpen += 1;
        continue;
      }
      afterQueryFilters.add(restaurant);
    }
    if (afterQueryFilters.isEmpty) {
      return DiscoveryDiagnosticReport(
        latitude: destination.latitude,
        longitude: destination.longitude,
        locationKind: presentation.kind,
        selectedByCustomer: destination.selectedByCustomer,
        isLiveGpsDefault: destination.isLiveGpsDefault,
        serviceable: true,
        geohash4Cells: cells,
        queryCountByCell: queryCountByCell,
        rawDocumentsReturned: raw,
        removedNotVisible: removedNotVisible,
        removedNotOpen: removedNotOpen,
        removedNotListable: 0,
        removedInvalidCoordinates: 0,
        removedOutside15km: 0,
        finalCount: 0,
        firstEmptyStage: DiscoveryEmptyStage.visibilityOrOpenFilter,
      );
    }

    var removedNotListable = 0;
    final listable = <RestaurantPublicProbe>[];
    for (final restaurant in afterQueryFilters) {
      if (!restaurant.isListable) {
        removedNotListable += 1;
        continue;
      }
      listable.add(restaurant);
    }
    if (listable.isEmpty) {
      return DiscoveryDiagnosticReport(
        latitude: destination.latitude,
        longitude: destination.longitude,
        locationKind: presentation.kind,
        selectedByCustomer: destination.selectedByCustomer,
        isLiveGpsDefault: destination.isLiveGpsDefault,
        serviceable: true,
        geohash4Cells: cells,
        queryCountByCell: queryCountByCell,
        rawDocumentsReturned: raw,
        removedNotVisible: removedNotVisible,
        removedNotOpen: removedNotOpen,
        removedNotListable: removedNotListable,
        removedInvalidCoordinates: 0,
        removedOutside15km: 0,
        finalCount: 0,
        firstEmptyStage: DiscoveryEmptyStage.listableFilter,
      );
    }

    var removedInvalidCoordinates = 0;
    var removedOutside15km = 0;
    final inRange = <RestaurantPublicProbe>[];
    for (final restaurant in listable) {
      final entity = RestaurantEntity(
        id: restaurant.restaurantId,
        name: restaurant.restaurantId,
        description: '',
        logoUrl: '',
        coverImageUrl: '',
        address: '',
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
        rating: 0,
        totalRatings: 0,
        deliveryTime: 0,
        deliveryFee: 0,
        minimumOrderAmount: 0,
        isPureVeg: false,
        isOpen: restaurant.isOpen,
        isFeatured: false,
        openingTime: '',
        closingTime: '',
        cuisines: const [],
        isCustomerVisible: restaurant.isCustomerVisible,
        isActive: restaurant.isActive,
        approvedFoodCount: restaurant.approvedFoodCount,
        onboardingStatus: restaurant.onboardingStatus,
        isVerified: restaurant.isVerified,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final km = RestaurantDeliveryRange.distanceKm(
        restaurant: entity,
        destination: destination,
      );
      if (km == null) {
        removedInvalidCoordinates += 1;
        continue;
      }
      if (km > RestaurantDeliveryRange.maxDistanceKm) {
        removedOutside15km += 1;
        continue;
      }
      inRange.add(restaurant);
    }

    DiscoveryEmptyStage stage = DiscoveryEmptyStage.none;
    if (inRange.isEmpty) {
      stage = removedInvalidCoordinates > 0
          ? DiscoveryEmptyStage.invalidRestaurantCoordinates
          : DiscoveryEmptyStage.outside15km;
    }

    return DiscoveryDiagnosticReport(
      latitude: destination.latitude,
      longitude: destination.longitude,
      locationKind: presentation.kind,
      selectedByCustomer: destination.selectedByCustomer,
      isLiveGpsDefault: destination.isLiveGpsDefault,
      serviceable: true,
      geohash4Cells: cells,
      queryCountByCell: queryCountByCell,
      rawDocumentsReturned: raw,
      removedNotVisible: removedNotVisible,
      removedNotOpen: removedNotOpen,
      removedNotListable: removedNotListable,
      removedInvalidCoordinates: removedInvalidCoordinates,
      removedOutside15km: removedOutside15km,
      finalCount: inRange.length,
      firstEmptyStage: stage,
    );
  }

  static KnownRestaurantDiagnostic inspectRestaurant({
    required RestaurantPublicProbe restaurant,
    required UserLocation destination,
    required bool customerDestinationServiceable,
  }) {
    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(destination).toSet();
    final stored = restaurant.geohash4?.trim();
    final missing = stored == null || stored.isEmpty;
    final km = GeoDistance.calculateDistanceKm(
      latitude1: destination.latitude,
      longitude1: destination.longitude,
      latitude2: restaurant.latitude,
      longitude2: restaurant.longitude,
    );
    return KnownRestaurantDiagnostic(
      restaurantId: restaurant.restaurantId,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      geohash: restaurant.geohash,
      geohash4: restaurant.geohash4,
      computedGeohash4: restaurant.computedGeohash4,
      isCustomerVisible: restaurant.isCustomerVisible,
      isOpen: restaurant.isOpen,
      isListable: restaurant.isListable,
      geohash4InCustomerCells: !missing && cells.contains(stored),
      computedGeohash4InCustomerCells: cells.contains(
        restaurant.computedGeohash4,
      ),
      distanceKm: km,
      wouldPass15km:
          customerDestinationServiceable &&
          km != null &&
          km <= RestaurantDeliveryRange.maxDistanceKm,
      missingGeohash4: missing,
    );
  }
}
