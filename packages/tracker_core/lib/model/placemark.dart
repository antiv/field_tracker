import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../config/tracker_config.dart';
import '../utils/geo_utils.dart';
import '../utils/location_helper.dart';

/// A point on the route where something was recorded. The records themselves
/// are the app's type; the point knows only what the shared code needs.
class Placemark {
  int? id;
  DateTime? startDate;
  DateTime? endDate;
  double? latitude;
  double? longitude;

  /// Captured from the GPS fix that created this point — never entered by
  /// hand, and absent on points from before they were recorded.
  double? altitude;
  double? accuracy;
  String? description;
  List<TrackerRecord>? records = [];

  Placemark({
    this.id,
    this.startDate,
    this.endDate,
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    this.description,
    this.records,
  });

  /// Photo file names of every record on this point.
  List<String> get photoNames =>
      [for (final record in records ?? <TrackerRecord>[]) ...record.photos];

  /// The records travel under the `species` key: that is what every stored
  /// transect, backup and KML payload out there already uses.
  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
        'description': description,
        'species': records?.map((s) => s.toJson()).toList() ?? [],
      };

  static Placemark fromJson(Map<String, dynamic> json) => Placemark(
        id: json['id'] as int?,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        latitude: finiteOrNull(json['latitude'] as num?),
        longitude: finiteOrNull(json['longitude'] as num?),
        altitude: finiteOrNull(json['altitude'] as num?),
        accuracy: finiteOrNull(json['accuracy'] as num?),
        description: json['description'] as String?,
        records: recordsFromJson(json['species']),
      );

  /// A list of records as stored — in the database, a backup or a KML payload.
  static List<TrackerRecord> recordsFromJson(Object? list) =>
      (list as List<dynamic>?)
          ?.map((s) => TrackerConfig.current
              .recordFromJson(Map<String, dynamic>.from(s as Map)))
          .toList() ??
      [];

  static List<Placemark> fromMarkers(List<Marker> markers) {
    return markers.map((e) => Placemark.fromMarker(e, 1)).toList();
  }

  factory Placemark.fromMarker(Marker marker, int id) {
    return Placemark(
      id: id,
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      latitude: marker.position.latitude,
      longitude: marker.position.longitude,
      description: marker.infoWindow.title,
    );
  }

  Marker toMarker() {
    return Marker(
      markerId: MarkerId(id.toString()),
      position: LatLng(latitude!, longitude!),
      infoWindow: InfoWindow(
        title: description ?? 'Point ${(id ?? 0) + 1}',
      ),
      onTap: () => showMarkerInfo(id ?? 0),
    );
  }

  /// get duration in format hh:mm:ss - hh:mm:ss
  String get duration {
    if (startDate != null) {
      if (endDate == null) {
        return DateFormat('hh:mm:ss').format(startDate!);
      }
      return '${DateFormat('hh:mm:ss').format(startDate!)} - ${DateFormat('hh:mm:ss').format(endDate!)}';
    }
    return '';
  }

  String get durationWithDay {
    if (startDate != null) {
      if (endDate == null) {
        return DateFormat('dd.MM.yyyy HH:mm:ss').format(startDate!);
      }
      return '${DateFormat('dd.MM.yyyy HH:mm:ss').format(startDate!)} - ${DateFormat('HH:mm:ss').format(endDate!)}';
    }
    return '';
  }

  /// All records, one summary per line — the KML placemark description.
  String get summary {
    final list = records;
    if (list == null || list.isEmpty) return 'No species recorded';
    return list.map((e) => e.summary).join('\n');
  }

  LatLng get latLng {
    return LatLng(latitude!, longitude!);
  }

  /// Whether the map can place this point at all.
  bool get hasFiniteLatLng =>
      finiteOrNull(latitude) != null && finiteOrNull(longitude) != null;
}
