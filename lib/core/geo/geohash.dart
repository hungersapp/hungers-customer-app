/// Geohash encode + 8-neighbors. Precision 4 cells are ~39 km × 20 km,
/// which covers the platform's 15 km discovery/dispatch radius when the
/// centre cell and its neighbors are queried together.
class GeoHash {
  GeoHash._();

  static const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static const int cellPrecision = 4;
  static const int hashPrecision = 9;

  /// Max documents read per geohash4 cell.
  static const int limitPerCell = 40;

  /// Max cells in a covering (centre + 8 neighbors).
  static const int maxCells = 9;

  static const Map<String, List<String>> _neighbors = {
    'n': ['p0r21436x8zb9dcf5h7kjnmqesgutwvy', 'bc01fg45238967deuvhjyznpkmstqrwx'],
    's': ['14365h7k9dcfesgujnmqp0r2twvyx8zb', '238967debc01fg45kmstqrwxuvhjyznp'],
    'e': ['bc01fg45238967deuvhjyznpkmstqrwx', 'p0r21436x8zb9dcf5h7kjnmqesgutwvy'],
    'w': ['238967debc01fg45kmstqrwxuvhjyznp', '14365h7k9dcfesgujnmqp0r2twvyx8zb'],
  };

  static const Map<String, List<String>> _borders = {
    'n': ['prxz', 'bcfguvyz'],
    's': ['028b', '0145hjnp'],
    'e': ['bcfguvyz', 'prxz'],
    'w': ['0145hjnp', '028b'],
  };

  static String encode(
    double latitude,
    double longitude, {
    int precision = hashPrecision,
  }) {
    var idx = 0;
    var bit = 0;
    var evenBit = true;
    final chars = StringBuffer();
    var latMin = -90.0;
    var latMax = 90.0;
    var lonMin = -180.0;
    var lonMax = 180.0;

    while (chars.length < precision) {
      if (evenBit) {
        final lonMid = (lonMin + lonMax) / 2;
        if (longitude >= lonMid) {
          idx = idx * 2 + 1;
          lonMin = lonMid;
        } else {
          idx = idx * 2;
          lonMax = lonMid;
        }
      } else {
        final latMid = (latMin + latMax) / 2;
        if (latitude >= latMid) {
          idx = idx * 2 + 1;
          latMin = latMid;
        } else {
          idx = idx * 2;
          latMax = latMid;
        }
      }
      evenBit = !evenBit;
      if (bit < 4) {
        bit += 1;
      } else {
        chars.write(base32[idx]);
        bit = 0;
        idx = 0;
      }
    }
    return chars.toString();
  }

  static String cell4(double latitude, double longitude) {
    return encode(latitude, longitude, precision: cellPrecision);
  }

  static String _adjacent(String geohash, String direction) {
    final dir = direction.toLowerCase();
    if (geohash.isEmpty || !_neighbors.containsKey(dir)) {
      return geohash;
    }
    final lastCh = geohash[geohash.length - 1];
    var parent = geohash.substring(0, geohash.length - 1);
    final type = geohash.length % 2;
    if (_borders[dir]![type].contains(lastCh) && parent.isNotEmpty) {
      parent = _adjacent(parent, dir);
    }
    return parent + base32[_neighbors[dir]![type].indexOf(lastCh)];
  }

  /// Centre cell plus up to 8 neighbors, de-duplicated, at most [maxCells].
  static List<String> coveringCells({
    required double latitude,
    required double longitude,
  }) {
    final hash = cell4(latitude, longitude);
    if (hash.isEmpty) {
      return const [];
    }
    final n = _adjacent(hash, 'n');
    final s = _adjacent(hash, 's');
    final cells = <String>{
      hash,
      n,
      s,
      _adjacent(hash, 'e'),
      _adjacent(hash, 'w'),
      _adjacent(n, 'e'),
      _adjacent(n, 'w'),
      _adjacent(s, 'e'),
      _adjacent(s, 'w'),
    };
    return cells.take(maxCells).toList();
  }
}
