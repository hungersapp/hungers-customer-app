import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes a Google encoded polyline (`overview_polyline.points`).
///
/// Precision is 1e-5 degrees, the encoding used by the Directions API.
List<LatLng> decodeEncodedPolyline(String encoded) {
  if (encoded.isEmpty) {
    return const [];
  }
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  while (index < encoded.length) {
    final latitudeDelta = _decodeNext(encoded, index);
    index = latitudeDelta.nextIndex;
    latitude += latitudeDelta.value;

    if (index >= encoded.length) {
      break;
    }
    final longitudeDelta = _decodeNext(encoded, index);
    index = longitudeDelta.nextIndex;
    longitude += longitudeDelta.value;

    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }
  return points;
}

class _DecodedChunk {
  const _DecodedChunk(this.value, this.nextIndex);

  final int value;
  final int nextIndex;
}

_DecodedChunk _decodeNext(String encoded, int start) {
  var index = start;
  var result = 0;
  var shift = 0;
  var byte = 0;
  while (index < encoded.length) {
    byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
    if (byte < 0x20) {
      break;
    }
  }
  final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return _DecodedChunk(value, index);
}
