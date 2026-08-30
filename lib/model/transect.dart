import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:herp_tracker/model/placemark.dart';
import 'package:herp_tracker/model/point.dart';
import 'package:herp_tracker/utils/kml_utils.dart';
import 'package:herp_tracker/utils/kmz_utils.dart';
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
      ...kRecordColumnKeys,
      'csv_header.transect',
      'csv_header.point',
      'csv_header.photos',
    ].map((key) => _csvCell(key.tr())).join(','));

    markers?.forEach((placeMark) {
      placeMark.species?.forEach((species) {
        sb.writeln([
          ...placeMark.exportValues(species),
          name ?? '',
          '${(placeMark.id ?? 0) + 1}',
          species.photos.join('; '),
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

  /// Photo file names of every record in the transect.
  List<String> get photoNames =>
      [for (final marker in markers ?? <Placemark>[]) ...marker.photoNames];

  /// True when any record names a photo. Deliberately reads nothing off the
  /// disk — the history list calls this from its item builder on every frame.
  /// The export checks what is actually there, once, in [shareKML].
  bool get hasPhotos =>
      markers?.any((marker) =>
          marker.species?.any((record) => record.photos.isNotEmpty) ?? false) ??
      false;

  /// share transect as CSV file
  /// Both the file name and the share subject are built from this. Some share
  /// targets name the saved file after the subject, so it must not carry a
  /// path separator either — that is how an export came back as a KMZ with no
  /// extension and two stray directories in its name.
  String get _exportLabel =>
      sanitizeFileName('${name ?? ''} ${DateFormat('dd.MM.yyyy').format(startDate)}');

  String get _exportFileBase =>
      sanitizeFileName('${name ?? ''}-${DateFormat('dd-MM-yyyy').format(startDate)}');

  Future<void> shareCSV([Rect? sharePositionOrigin]) async {
    /// UTF-8 with BOM — labels carry č/ć/š/ž/đ and Excel needs the BOM to
    /// pick the right encoding
    Uint8List bytes =
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCSV())]);
    String path = await storeFileTemporarily(bytes, '$_exportFileBase.csv');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: _exportLabel,
      subject: _exportLabel,
      sharePositionOrigin: sharePositionOrigin,
    ));
  }

  /// Share the transect as KML, or as KMZ when there are photos to embed —
  /// a plain KML could only name them. This is the one place that asks the
  /// disk which of the named photos still exist.
  Future<void> shareKML([Rect? sharePositionOrigin]) async {
    final photos = hasPhotos ? KMZUtils.availablePhotos(this) : <String>[];
    final label = photos.isEmpty ? 'KML' : 'KMZ';
    final String path =
        await temporaryFilePath('$_exportFileBase.${label.toLowerCase()}');

    if (photos.isEmpty) {
      await File(path).writeAsBytes(utf8.encode(toKML()), flush: true);
    } else {
      await KMZUtils.writeKMZ(this, path, photos);
    }

    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: '$_exportLabel $label',
      subject: '$_exportLabel $label',
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
