import 'package:google_maps_flutter/google_maps_flutter.dart';

class Point {
  late double latitude;
  late double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  static Point fromJson(Map<String, dynamic> json) => Point()
    ..latitude = (json['latitude'] as num).toDouble()
    ..longitude = (json['longitude'] as num).toDouble();
}