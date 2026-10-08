import 'package:customer_app/core/geo/geohash.dart';
import 'package:customer_app/features/dashboard/domain/entities/category.dart';
import 'package:customer_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:customer_app/features/dashboard/domain/usecases/get_categories_usecase.dart';
import 'package:customer_app/features/location/domain/entities/user_location.dart';
import 'package:customer_app/features/restaurants/domain/entities/restaurant_entity.dart';
import 'package:customer_app/features/restaurants/domain/repositories/restaurant_repository.dart';
import 'package:customer_app/features/search/domain/entities/search_result_entity.dart';
import 'package:customer_app/features/search/domain/repositories/search_repository.dart';

/// Real city-centre coordinates for multi-city discovery tests.
class City {
  const City(this.name, this.state, this.latitude, this.longitude);

  final String name;
  final String state;
  final double latitude;
  final double longitude;
}

const madurai = City('Madurai', 'Tamil Nadu', 9.9252, 78.1198);
const thanjavur = City('Thanjavur', 'Tamil Nadu', 10.7870, 79.1378); // ~160 km
const chennai = City('Chennai', 'Tamil Nadu', 13.0827, 80.2707); // ~430 km
const bengaluru = City('Bengaluru', 'Karnataka', 12.9716, 77.5946); // ~370 km

/// One degree of latitude in kilometres, on the sphere the app's Haversine uses
/// (radius 6371 km). Used to place a restaurant a precise distance away.
const double kmPerLatitudeDegree = 111.19492664455873;

/// A restaurant that is fully customer-listable (visible, active, open,
/// approved, has approved food), so a test only varies what it cares about.
RestaurantEntity testRestaurant({
  required String id,
  double latitude = 9.9252,
  double longitude = 78.1198,
  double rating = 4.0,
  String? name,
  bool isFeatured = false,
}) {
  final now = DateTime(2026, 1, 1);
  return RestaurantEntity(
    id: id,
    name: name ?? id,
    description: '',
    logoUrl: '',
    coverImageUrl: '',
    address: '',
    latitude: latitude,
    longitude: longitude,
    rating: rating,
    totalRatings: 10,
    deliveryTime: 30,
    deliveryFee: 0,
    minimumOrderAmount: 0,
    isPureVeg: false,
    isOpen: true,
    isFeatured: isFeatured,
    openingTime: '',
    closingTime: '',
    cuisines: const [],
    isCustomerVisible: true,
    isActive: true,
    approvedFoodCount: 5,
    onboardingStatus: 'approved',
    isVerified: true,
    createdAt: now,
    updatedAt: now,
  );
}

/// A restaurant in [city].
RestaurantEntity restaurantIn(
  City city,
  String id, {
  double rating = 4.0,
  double dLatKm = 0,
}) {
  return testRestaurant(
    id: id,
    latitude: city.latitude + dLatKm / kmPerLatitudeDegree,
    longitude: city.longitude,
    rating: rating,
  );
}

/// A delivery destination in [city]; door and street make it a SELECTED
/// address (as the address editor saves it) unless [selected] is false, which
/// gives a GPS-derived current-location default.
UserLocation destinationIn(
  City city, {
  bool selected = true,
  String? pincode = '625001',
  double dLatKm = 0,
}) {
  return UserLocation(
    latitude: city.latitude + dLatKm / kmPerLatitudeDegree,
    longitude: city.longitude,
    city: city.name,
    state: city.state,
    pincode: pincode,
    doorNumber: selected ? '12A' : '',
    street: selected ? 'Main Road' : '',
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// [destination] as an EXPLICIT selection: the customer picked it in the
/// selector (a searched place by default, or a saved address), so it stays
/// the active location until they change it — GPS never replaces it
/// (LocationRefreshPolicy). Without this, [destinationIn] is a LEGACY
/// address: saved before the source was recorded, and replaceable by GPS.
UserLocation explicitly(
  UserLocation destination, [
  LocationSource source = LocationSource.manualSelection,
]) {
  return destination.copyWith(selectedByCustomer: true, source: source);
}

/// What the datasource hands back before any scoping: every customer-listable
/// restaurant in the country. The use cases and providers under test must
/// scope this to the delivery destination.
class NationwideRestaurantRepository implements RestaurantRepository {
  NationwideRestaurantRepository(this.restaurants);

  final List<RestaurantEntity> restaurants;
  int getAllCalls = 0;
  int popularCalls = 0;
  int discoverableCalls = 0;
  List<String> lastGeohash4Cells = const [];

  @override
  Future<List<RestaurantEntity>> getDiscoverableRestaurants({
    required List<String> geohash4Cells,
    bool featuredOnly = false,
  }) async {
    discoverableCalls += 1;
    lastGeohash4Cells = geohash4Cells;
    final cells = geohash4Cells.toSet();
    final source = featuredOnly
        ? restaurants.where((r) => r.isFeatured)
        : restaurants;
    return source
        .where(
          (restaurant) => cells.contains(
            GeoHash.cell4(restaurant.latitude, restaurant.longitude),
          ),
        )
        .toList();
  }

  @override
  Future<List<RestaurantEntity>> getAllRestaurants() async {
    getAllCalls += 1;
    return restaurants;
  }

  @override
  Future<List<RestaurantEntity>> getFeaturedRestaurants() async =>
      restaurants.where((r) => r.isFeatured).toList();

  /// The datasource's own popular query: the national top 20 by rating.
  @override
  Future<List<RestaurantEntity>> getPopularRestaurants() async {
    popularCalls += 1;
    return ([
      ...restaurants,
    ]..sort((a, b) => b.rating.compareTo(a.rating))).take(20).toList();
  }

  @override
  Future<List<RestaurantEntity>> getNearbyRestaurants() async => restaurants;

  /// Like the real repository: only customer-listable restaurants exist here,
  /// so an unknown id is null.
  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async {
    for (final restaurant in restaurants) {
      if (restaurant.id == restaurantId) {
        return restaurant;
      }
    }
    return null;
  }

  /// The datasource's keyword match, nationwide: name contains the keyword.
  @override
  Future<List<RestaurantEntity>> searchRestaurants(String keyword) async => [
    for (final restaurant in restaurants)
      if (restaurant.name.toLowerCase().contains(keyword.toLowerCase()))
        restaurant,
  ];
}

/// A restaurant search hit, as the datasource returns it.
SearchResultEntity restaurantResult(String id) => SearchResultEntity(
  id: id,
  title: id,
  subtitle: '',
  imageUrl: '',
  type: SearchResultType.restaurant,
);

/// A food search hit sold by [restaurantId].
SearchResultEntity foodResult(String id, {required String restaurantId}) =>
    SearchResultEntity(
      id: id,
      title: id,
      subtitle: restaurantId,
      imageUrl: '',
      type: SearchResultType.food,
      restaurantId: restaurantId,
    );

/// What the search datasource hands back before scoping: every keyword match
/// in the country, restaurants and foods alike. The use case under test must
/// scope this to the delivery destination.
class NationwideSearchRepository implements SearchRepository {
  NationwideSearchRepository(this.matches);

  final List<SearchResultEntity> matches;

  /// One entry per datasource query, so a test can see whether a search ran.
  final List<String> queries = [];
  int get calls => queries.length;
  int lastLimit = 20;
  List<String> lastGeohash4Cells = const [];
  List<String> lastRestaurantIds = const [];

  List<SearchResultEntity> _of(SearchResultType? type) => [
    for (final match in matches)
      if (type == null || match.type == type) match,
  ];

  List<SearchResultEntity> _bounded(
    Iterable<SearchResultEntity> results,
    int limit,
  ) {
    return results.take(limit).toList();
  }

  @override
  Future<List<SearchResultEntity>> searchAll(
    String query, {
    List<String> geohash4Cells = const [],
    List<String> restaurantIds = const [],
    int limit = 20,
  }) async {
    queries.add(query);
    lastLimit = limit;
    lastGeohash4Cells = geohash4Cells;
    lastRestaurantIds = restaurantIds;
    if (geohash4Cells.isEmpty) {
      return const [];
    }
    final allowed = restaurantIds.toSet();
    return matches
        .where((match) {
          if (match.type == SearchResultType.category) {
            return true;
          }
          if (match.type == SearchResultType.food) {
            return allowed.contains(match.restaurantId);
          }
          return true;
        })
        .take(limit * 2)
        .toList();
  }

  @override
  Future<List<SearchResultEntity>> searchRestaurants(
    String query, {
    List<String> geohash4Cells = const [],
    int limit = 20,
  }) async {
    queries.add(query);
    lastLimit = limit;
    lastGeohash4Cells = geohash4Cells;
    if (geohash4Cells.isEmpty) {
      return const [];
    }
    return _bounded(_of(SearchResultType.restaurant), limit);
  }

  @override
  Future<List<SearchResultEntity>> searchFoods(
    String query, {
    List<String> restaurantIds = const [],
    int limit = 20,
  }) async {
    queries.add(query);
    lastLimit = limit;
    lastRestaurantIds = restaurantIds;
    if (restaurantIds.isEmpty) {
      return const [];
    }
    final allowed = restaurantIds.toSet();
    return _bounded(
      _of(
        SearchResultType.food,
      ).where((match) => allowed.contains(match.restaurantId)),
      limit,
    );
  }
}

class EmptyDashboardRepository implements DashboardRepository {
  const EmptyDashboardRepository();

  @override
  Future<List<Category>> getCategories() async => const [];
}

final emptyCategoriesUseCase = GetCategoriesUseCase(
  const EmptyDashboardRepository(),
);
