import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Coordinates that can actually be put on the map.
///
/// The Maps renderer rejects a camera target or marker with NaN in it by
/// crashing the process on its own thread, where nothing catches it — and
/// `double.parse('NaN')` is a valid parse in Dart, so a KML or a backup
/// carrying the literal would otherwise sail straight through an import.
bool isFiniteLatLng(LatLng latLng) =>
    latLng.latitude.isFinite && latLng.longitude.isFinite;

/// A persisted coordinate, or null when it is missing or not a real number.
double? finiteOrNull(num? value) {
  final d = value?.toDouble();
  return d != null && d.isFinite ? d : null;
}
