import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/geo_utils.dart';

class Point {
  late double latitude;
  late double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Null for a point the map could not place; callers drop those.
  static Point? fromJson(Map<String, dynamic> json) {
    final latitude = finiteOrNull(json['latitude'] as num?);
    final longitude = finiteOrNull(json['longitude'] as num?);
    if (latitude == null || longitude == null) return null;
    return Point()
      ..latitude = latitude
      ..longitude = longitude;
  }
}