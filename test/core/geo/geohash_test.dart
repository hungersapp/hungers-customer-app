import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/geo/geohash.dart';
import 'package:customer_app/features/restaurants/domain/restaurant_discovery_query.dart';

import '../../helpers/discovery_fixtures.dart';

void main() {
  test('Madurai and Chennai encode to different geohash4 cells', () {
    expect(GeoHash.cell4(madurai.latitude, madurai.longitude), isNotEmpty);
    expect(
      GeoHash.cell4(madurai.latitude, madurai.longitude),
      isNot(GeoHash.cell4(chennai.latitude, chennai.longitude)),
    );
  });

  test('covering cells are bounded and include the centre cell', () {
    final cells = GeoHash.coveringCells(
      latitude: madurai.latitude,
      longitude: madurai.longitude,
    );
    expect(cells, isNotEmpty);
    expect(cells.length, lessThanOrEqualTo(GeoHash.maxCells));
    expect(cells, contains(GeoHash.cell4(madurai.latitude, madurai.longitude)));
    expect(cells.toSet().length, cells.length);
  });

  test('a far city is not in the destination covering set', () {
    final maduraiCells = GeoHash.coveringCells(
      latitude: madurai.latitude,
      longitude: madurai.longitude,
    ).toSet();
    expect(
      maduraiCells.contains(GeoHash.cell4(chennai.latitude, chennai.longitude)),
      isFalse,
    );
  });

  test('unusable destination yields no discovery cells', () {
    expect(RestaurantDiscoveryQuery.geohash4CellsFor(null), isEmpty);
  });

  test('usable destination yields covering cells', () {
    final cells = RestaurantDiscoveryQuery.geohash4CellsFor(
      destinationIn(madurai),
    );
    expect(cells, isNotEmpty);
    expect(cells.length, lessThanOrEqualTo(9));
  });
}
