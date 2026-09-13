import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bird_tracker/model/placemark.dart';
import 'package:bird_tracker/model/point.dart';
import 'package:bird_tracker/model/species.dart';
import 'package:bird_tracker/utils/kml_utils.dart';
import 'package:bird_tracker/utils/kmz_utils.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../service/data_service.dart';
import '../utils/file_utils.dart';
import '../utils/geo_utils.dart';
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
            .nonNulls
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

  /// convert transect to CSV
  String toCSV() {
    final sb = StringBuffer();
    sb.writeln(
        'Species, Date, Time (from - to), Time, Latitude,Longitude,Latitude(DMS),Longitude(DMS),Count, Behavior, Stratification, Direction, Code');
    markers?.forEach((placeMark) {
      /// A KML imported from before the ExtendedData payload carries no
      /// timestamps, so this is genuinely null — the same empty cell
      /// [Placemark.duration] already falls back to, rather than a crash on
      /// the way to the share sheet.
      final DateTime? date = placeMark.startDate;
      placeMark.species?.forEach((species) {
        sb.writeln('${species.species},'
            '${date == null ? '' : DateFormat('dd/MM/yyyy').format(date)},'
            '${placeMark.duration},'
            '${species.time},'
            '${placeMark.latitude},'
            '${placeMark.longitude},'
            '${convertLatLng(placeMark.latitude!, true)},'
            '${convertLatLng(placeMark.longitude!, false)},'
            '${species.count},'
            '"${species.description ?? ''}",'
            '${species.stratification != null ? species.stratification?.toShortString() : ''},'
            '${species.direction != null ? species.direction?.toShortString() : ''},'
            '${species.code ?? ''}');
      });
    });
    return sb.toString();
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

  /// Both the file name and the share subject are built from this. Some share
  /// targets name the saved file after the subject, so it must not carry a
  /// path separator either — that is how an export came back as a KMZ with no
  /// extension and two stray directories in its name.
  String get _exportLabel => sanitizeFileName(
      '${name ?? ''} ${DateFormat('dd.MM.yyyy').format(startDate)}');

  String get _exportFileBase => sanitizeFileName(
      '${name ?? ''}-${DateFormat('dd-MM-yyyy').format(startDate)}');

  /// share transect as CSV file
  Future<void> shareCSV([Rect? sharePositionOrigin]) async {
    /// UTF-8 with BOM — species names and behaviour notes carry č/ć/š/ž/đ and
    /// Excel needs the BOM to pick the right encoding
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
    final first = points?.map((p) => p.latLng).where(isFiniteLatLng).firstOrNull ??
        markers
            ?.where((m) => m.hasFiniteLatLng)
            .map((m) => m.latLng)
            .firstOrNull;
    if (first != null) {
      goToLocation(first, DataService().controller, DataService().completer);
    }
  }
}
