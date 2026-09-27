import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';

import '../config/tracker_config.dart';
import '../service/data_service.dart';
import '../utils/file_utils.dart';
import '../utils/geo_utils.dart';
import '../utils/kml_utils.dart';
import '../utils/kmz_utils.dart';
import '../utils/location_helper.dart';
import 'placemark.dart';
import 'point.dart';

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
    ..points =
        (json['points'] as List<dynamic>?)
            ?.map((p) => Point.fromJson(p as Map<String, dynamic>))
            .nonNulls
            .toList() ??
        []
    ..markers =
        (json['markers'] as List<dynamic>?)
            ?.map((m) => Placemark.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

  /// Id for a new point: one past the highest in use. The count of points
  /// would hand out an id that is still taken as soon as a point had been
  /// deleted, and two map markers with one id show as one.
  int get nextMarkerId => (markers ?? const <Placemark>[]).fold<int>(
    0,
    (next, m) => m.id != null && m.id! >= next ? m.id! + 1 : next,
  );

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

  /// get duration in format HH:mm:ss - HH:mm:ss
  String get fromTo {
    if (endDate == null) {
      return DateFormat('HH:mm:ss').format(startDate);
    }
    return '${DateFormat('HH:mm:ss').format(startDate)} - ${DateFormat('HH:mm:ss').format(endDate!)}';
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

  /// get from - to date in format dd.MM.yyyy HH:mm:ss - HH:mm:ss
  String get dateRange {
    /// if same day return end in HH:mm:ss format
    if (startDate.year == endDate?.year &&
        startDate.month == endDate?.month &&
        startDate.day == endDate?.day) {
      return '${DateFormat('dd.MM.yyyy HH:mm:ss').format(startDate)} - ${DateFormat('HH:mm:ss').format(endDate!)}';
    } else if (endDate != null) {
      return '${DateFormat('dd.MM.yyyy HH:mm:ss').format(startDate)} - ${DateFormat('dd.MM.yyyy HH:mm:ss').format(endDate!)}';
    }

    /// start date only
    return DateFormat('dd.MM.yyyy HH:mm:ss').format(startDate);
  }

  /// Convert the transect to CSV: the app's record columns, then the
  /// transect name, the point number and the photo names. Headers follow the
  /// app language, so the sheet the surveyor pastes into reads naturally.
  String toCSV() => csvOf([this]);

  /// Several transects in one sheet: one header, then every transect's rows.
  /// The transect column already tells them apart.
  static String csvOf(Iterable<Transect> transects) {
    final config = TrackerConfig.current;
    final sb = StringBuffer();
    sb.writeln(
      [
        ...config.exportColumnLabels(),
        'csv_header.transect'.tr(),
        'csv_header.point'.tr(),
        'csv_header.photos'.tr(),
        'csv_header.point_photos'.tr(),
      ].map(csvCell).join(','),
    );
    for (final transect in transects) {
      for (final point in transect.markers ?? const <Placemark>[]) {
        for (final record in point.records ?? const <TrackerRecord>[]) {
          sb.writeln(
            [
              ...config.exportValues(point, record),
              transect.name ?? '',
              '${(point.id ?? 0) + 1}',
              record.photos.join('; '),
              point.photos.join('; '),
            ].map(csvCell).join(','),
          );
        }
      }
    }
    return sb.toString();
  }

  /// Values carry commas and quotes (notes especially) — quote every cell
  /// that needs it, per RFC 4180.
  static String csvCell(String value) {
    if (value.contains(RegExp(r'[",\n\r]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// convert transect to KML
  String toKML() {
    return KMLUtils.generateKML(this);
  }

  /// Photo file names of every point and record in the transect.
  List<String> get photoNames => [
    for (final marker in markers ?? <Placemark>[]) ...marker.photoNames,
  ];

  /// True when any point or record names a photo. Deliberately reads nothing off the
  /// disk — the history list calls this from its item builder on every frame.
  /// The export checks what is actually there, once, in [shareKML].
  bool get hasPhotos =>
      markers?.any(
        (marker) =>
            marker.photos.isNotEmpty ||
            (marker.records?.any((record) => record.photos.isNotEmpty) ??
                false),
      ) ??
      false;

  /// Both the file name and the share subject are built from this. Some share
  /// targets name the saved file after the subject, so it must not carry a
  /// path separator either — that is how an export came back as a KMZ with no
  /// extension and two stray directories in its name.
  String get _exportLabel => sanitizeFileName(
    '${name ?? ''} ${DateFormat('dd.MM.yyyy').format(startDate)}',
  );

  String get _exportFileBase => sanitizeFileName(
    '${name ?? ''}-${DateFormat('dd-MM-yyyy').format(startDate)}',
  );

  /// share transect as CSV file
  Future<void> shareCSV([Rect? sharePositionOrigin]) =>
      shareCSVOf([this], sharePositionOrigin);

  /// One CSV for all of [transects] — a sheet is where they get compared.
  static Future<void> shareCSVOf(
    List<Transect> transects, [
    Rect? sharePositionOrigin,
  ]) async {
    if (transects.isEmpty) return;
    final single = transects.length == 1 ? transects.single : null;

    /// UTF-8 with BOM — species names and notes carry č/ć/š/ž/đ and Excel
    /// needs the BOM to pick the right encoding
    Uint8List bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csvOf(transects)),
    ]);
    final base = single?._exportFileBase ?? _multiExportFileBase(transects);
    final label = single?._exportLabel ?? _multiExportLabel(transects);
    String path = await storeFileTemporarily(bytes, '$base.csv');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: label,
        subject: label,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Share the transect as KML, or as KMZ when there are photos to embed —
  /// a plain KML could only name them.
  Future<void> shareKML([Rect? sharePositionOrigin]) =>
      shareKMLOf([this], sharePositionOrigin);

  /// One KML/KMZ per transect, all in one share: an import reads a file as
  /// one transect, so merging them would fuse the routes on the way back.
  static Future<void> shareKMLOf(
    List<Transect> transects, [
    Rect? sharePositionOrigin,
  ]) async {
    if (transects.isEmpty) return;
    final files = <XFile>[];
    final used = <String>{};
    var anyKmz = false;
    for (final transect in transects) {
      /// two transects with the same name on the same day would otherwise
      /// write over each other's file
      var base = transect._exportFileBase;
      if (!used.add(base)) {
        base = '$base-${transect.id}';
        used.add(base);
      }
      final (path, isKmz) = await transect._writeKMLFile(base);
      anyKmz |= isKmz;
      files.add(XFile(path));
    }
    final label = transects.length == 1
        ? '${transects.single._exportLabel} ${anyKmz ? 'KMZ' : 'KML'}'
        : _multiExportLabel(transects);
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: label,
        subject: label,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Writes the transect as `<base>.kml`, or `<base>.kmz` when there are
  /// photos on disk to embed. This is the one place that asks the disk which
  /// of the named photos still exist.
  Future<(String, bool)> _writeKMLFile(String base) async {
    final photos = hasPhotos ? KMZUtils.availablePhotos(this) : <String>[];
    final isKmz = photos.isNotEmpty;
    final String path = await temporaryFilePath(
      '$base.${isKmz ? 'kmz' : 'kml'}',
    );
    if (isKmz) {
      await KMZUtils.writeKMZ(this, path, photos);
    } else {
      await File(path).writeAsBytes(utf8.encode(toKML()), flush: true);
    }
    return (path, isKmz);
  }

  static String _multiExportLabel(List<Transect> transects) => sanitizeFileName(
    '${TrackerConfig.current.appTitle} '
    '${'transects_export'.tr(args: ['${transects.length}'])}',
  );

  static String _multiExportFileBase(List<Transect> transects) =>
      sanitizeFileName(
        '${TrackerConfig.current.appTitle}-${transects.length}-'
        '${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
      );

  void goToFirst() {
    final first =
        points?.map((p) => p.latLng).where(isFiniteLatLng).firstOrNull ??
        markers
            ?.where((m) => m.hasFiniteLatLng)
            .map((m) => m.latLng)
            .firstOrNull;
    if (first != null) {
      goToLocation(first, DataService().controller, DataService().completer);
    }
  }
}
