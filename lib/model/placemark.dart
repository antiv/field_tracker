import 'package:herp_tracker/model/species.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../configuration/field_options.dart';
import '../utils/location_helper.dart';

/// The export columns of one record, in the order of "Vrste za aplikaciju.xlsx".
/// CSV and the KML balloon are built from this same list, so a new record field
/// reaches both without a second edit. Transect name, point number and the
/// photo list sit outside it — each export places those where it wants them.
const List<String> kRecordColumnKeys = [
  'csv_header.species',
  'csv_header.date',
  'csv_header.observed_at',
  'csv_header.lat',
  'csv_header.lon',
  'csv_header.altitude',
  'csv_header.accuracy',
  'csv_header.locality',
  'csv_header.stage',
  'csv_header.sex',
  'csv_header.data_type',
  'csv_header.method',
  'csv_header.habitat',
  'csv_header.water_bed',
  'csv_header.count',
  'csv_header.abundance',
  'csv_header.note',
];

class Placemark {
  int? id;
  DateTime? startDate;
  DateTime? endDate;
  double? latitude;
  double? longitude;

  /// Captured from the GPS fix that created this point — never entered by hand.
  double? altitude;
  double? accuracy;
  String? description;
  List<Species>? species = [];

  Placemark({
    this.id,
    this.startDate,
    this.endDate,
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
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
        'altitude': altitude,
        'accuracy': accuracy,
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
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
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

  /// Values for [kRecordColumnKeys], same order, same length. Empty rather
  /// than absent for a field the surveyor left blank — the balloon shows the
  /// row as "No value", which is information too.
  List<String> exportValues(Species record) => [
        record.species,
        DateFormat('dd.MM.yyyy').format(record.observedAt),
        DateFormat('dd.MM.yyyy HH:mm:ss').format(record.observedAt),
        latitude?.toString() ?? '',
        longitude?.toString() ?? '',
        altitude?.toStringAsFixed(1) ?? '',
        accuracy?.toStringAsFixed(1) ?? '',
        record.locality ?? '',
        optionLabel(record.stage),
        optionLabel(record.sex),
        optionLabel(record.dataType),
        optionLabel(record.method),
        optionLabel(record.habitat),
        optionLabel(record.waterBed),
        record.count?.toString() ?? '',
        optionLabel(record.abundance),
        record.note ?? '',
      ];

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
}
