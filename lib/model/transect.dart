import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:herp_tracker/configuration/field_options.dart';
import 'package:herp_tracker/model/placemark.dart';
import 'package:herp_tracker/model/point.dart';
import 'package:herp_tracker/utils/kml_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../service/data_service.dart';
import '../utils/file_utils.dart';
import '../utils/location_helper.dart';

class Transect {
  int id = 0;
  late DateTime startDate;
  String? name;
  DateTime? endDate;
  String? description;
  List<Point>? points;
  List<Placemark>? markers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'name': name,
        'endDate': endDate?.toIso8601String(),
        'description': description,
        'points': points?.map((p) => p.toJson()).toList() ?? [],
        'markers': markers?.map((m) => m.toJson()).toList() ?? [],
      };

  static Transect fromJson(Map<String, dynamic> json) => Transect()
    ..id = (json['id'] as int?) ?? 0
    ..startDate = DateTime.parse(json['startDate'] as String)
    ..name = json['name'] as String?
    ..endDate = json['endDate'] != null
        ? DateTime.parse(json['endDate'] as String)
        : null
    ..description = json['description'] as String?
    ..points = (json['points'] as List<dynamic>?)
            ?.map((p) => Point.fromJson(p as Map<String, dynamic>))
            .toList() ??
        []
    ..markers = (json['markers'] as List<dynamic>?)
            ?.map((m) => Placemark.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

  void addMarker(Placemark marker) {
    markers?.add(marker);
  }

  void updateMarker(Placemark marker) {
    if (markers != null) {
      final index = markers!.indexWhere((element) => element.id == marker.id);
      if (index != -1) {
        markers![index] = marker;
      }
    }
  }

  void deleteMarker(Placemark marker) {
    markers?.remove(marker);
  }

  String get duration {
    if (endDate != null) {
      final duration = endDate!.difference(startDate);
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    }
    return '';
  }

  /// get duration in format hh:mm:ss - hh:mm:ss
  String get fromTo {
    if (endDate == null) {
      return DateFormat('hh:mm:ss').format(startDate);
    }
    return '${DateFormat('hh:mm:ss').format(startDate)} - ${DateFormat('hh:mm:ss').format(endDate!)}';
  }

  double get distance {
    if (points != null) {
      return calculateDistance(points!.map((e) => e.latLng).toList());
    }
    return 0;
  }

  /// distance in KM, m
  String get distanceString {
    return '${distance.toStringAsFixed(2)} km';
  }

  /// get the total number of species recorded
  int get speciesCount {
    if (markers != null) {
      return markers!.length;
    }
    return 0;
  }

  /// get from - to date in format dd.mm.yyyy hh:mm - hh:mm
  String get dateRange {
    /// if same day return end in hh:mm format
    if (startDate.year == endDate?.year &&
        startDate.month == endDate?.month &&
        startDate.day == endDate?.day) {
      return '${DateFormat('dd.MM.yyyy hh:mm:ss').format(startDate)} - ${DateFormat('hh:mm:ss').format(endDate!)}';
    } else if (endDate != null) {
      return '${DateFormat('dd.MM.yyyy hh:mm:ss').format(startDate)} - ${DateFormat('dd.MM.yyyy hh:mm:ss').format(endDate!)}';
    }

    /// start date only
    return DateFormat('dd.MM.yyyy hh:mm:ss').format(startDate);
  }

  /// Convert transect to CSV. Column order matches "Vrste za aplikaciju.xlsx"
  /// so the export can be pasted straight into that sheet; headers and option
  /// labels follow the app language.
  String toCSV() {
    final sb = StringBuffer();
    sb.writeln([
      'csv.species',
      'csv.date',
      'csv.observed_at',
      'csv.lat',
      'csv.lon',
      'csv.altitude',
      'csv.accuracy',
      'csv.locality',
      'csv.stage',
      'csv.sex',
      'csv.data_type',
      'csv.method',
      'csv.habitat',
      'csv.water_bed',
      'csv.count',
      'csv.abundance',
      'csv.note',
      'csv.transect',
      'csv.point',
    ].map((key) => _csvCell(key.tr())).join(','));

    markers?.forEach((placeMark) {
      placeMark.species?.forEach((species) {
        sb.writeln([
          species.species,
          DateFormat('dd.MM.yyyy').format(species.observedAt),
          DateFormat('dd.MM.yyyy HH:mm:ss').format(species.observedAt),
          placeMark.latitude?.toString() ?? '',
          placeMark.longitude?.toString() ?? '',
          placeMark.altitude?.toStringAsFixed(1) ?? '',
          placeMark.accuracy?.toStringAsFixed(1) ?? '',
          species.locality ?? '',
          optionLabel(species.stage),
          optionLabel(species.sex),
          optionLabel(species.dataType),
          optionLabel(species.method),
          optionLabel(species.habitat),
          optionLabel(species.waterBed),
          species.count?.toString() ?? '',
          optionLabel(species.abundance),
          species.note ?? '',
          name ?? '',
          '${(placeMark.id ?? 0) + 1}',
        ].map(_csvCell).join(','));
      });
    });
    return sb.toString();
  }

  /// Localized values carry commas and quotes (notes especially) — quote every
  /// cell that needs it, per RFC 4180.
  static String _csvCell(String value) {
    if (value.contains(RegExp(r'[",\n\r]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// convert transect to KML
  String toKML() {
    return KMLUtils.generateKML(this);
  }

  /// share transect as CSV file
  Future<void> shareCSV([Rect? sharePositionOrigin]) async {
    /// UTF-8 with BOM — labels carry č/ć/š/ž/đ and Excel needs the BOM to
    /// pick the right encoding
    Uint8List bytes =
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCSV())]);
    String path = await storeFileTemporarily(
        bytes, '$name-${DateFormat('dd-MM-yyyy').format(startDate)}.csv');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: '$name ${DateFormat('dd/MM/yyyy').format(startDate)}',
      subject: '$name ${DateFormat('dd/MM/yyyy').format(startDate)}',
      sharePositionOrigin: sharePositionOrigin,
    ));
  }

  /// share transect as KML file
  Future<void> shareKML([Rect? sharePositionOrigin]) async {
    Uint8List bytes = Uint8List.fromList(utf8.encode(toKML()));
    String path = await storeFileTemporarily(
        bytes, '$name-${DateFormat('dd-MM-yyyy').format(startDate)}.kml');

    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: '$name ${DateFormat('dd/MM/yyyy').format(startDate)} as KML',
      subject: '$name ${DateFormat('dd/MM/yyyy').format(startDate)} as KML',
      sharePositionOrigin: sharePositionOrigin,
    ));
  }

  void goToFirst() {
    if (points?.isNotEmpty ?? false) {
      goToLocation(points!.first.latLng, DataService().controller,
          DataService().completer);
    } else {
      if (markers?.isNotEmpty ?? false) {
        goToLocation(markers!.first.latLng, DataService().controller,
            DataService().completer);
      }
    }
  }
}
