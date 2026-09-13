import 'package:bird_tracker/model/species.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../utils/geo_utils.dart';
import '../utils/location_helper.dart';

class Placemark {
  int? id;
  DateTime? startDate;
  DateTime? endDate;
  double? latitude;
  double? longitude;
  String? description;
  List<Species>? species = [];

  Placemark({
    this.id,
    this.startDate,
    this.endDate,
    this.latitude,
    this.longitude,
    this.description,
    this.species,
  });

  /// Photo file names of every record on this point.
  List<String> get photoNames =>
      [for (final record in species ?? <Species>[]) ...record.photos];

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'species': species?.map((s) => s.toJson()).toList() ?? [],
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
        description: json['description'] as String?,
        species: (json['species'] as List<dynamic>?)
                ?.map((s) => Species.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

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

  String get speciesString {
    /// return all species in format: species1, species2, species3
    /// if no species, return 'No species recorded'
    if (species != null) {
      if (species!.isNotEmpty) {
        return species!.map((e) => e.speciesString).join('\n');
      } else {
        return 'No species recorded';
      }
    } else {
      return 'No species recorded';
    }
  }

  LatLng get latLng {
    return LatLng(latitude!, longitude!);
  }

  /// Whether the map can place this point at all.
  bool get hasFiniteLatLng =>
      finiteOrNull(latitude) != null && finiteOrNull(longitude) != null;
}

