// Class to create .kml file from a transect, using xml package
import 'dart:convert';
import 'dart:developer';

import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xml/xml.dart';

import '../config/tracker_config.dart';
import '../model/placemark.dart';
import '../model/point.dart';
import '../model/transect.dart';
import 'geo_utils.dart';

/// Name of the ExtendedData entry carrying the machine-readable records.
///
/// A plain `<Data name="records">` is what viewers render as a name/value
/// table — Google My Maps would show the raw JSON to the user. KML 2.2 lets
/// ExtendedData hold arbitrary namespaced content that renderers must ignore,
/// so the payload travels under the app's [TrackerConfig.kmlNamespace]
/// instead. It is read back by local name whatever the namespace, so a file
/// from any of the tracker apps, or from before the namespace, still imports.
const String kRecordsDataName = 'records';

/// Folder KMZ archives keep their photos in, and the prefix `<img src>` uses.
const String kKmzFilesDir = 'files';

/// The KML entry inside a KMZ archive.
const String kKmzDocName = 'doc.kml';

class KMLUtils {
  static final KMLUtils _singleton = KMLUtils._internal();

  factory KMLUtils() {
    return _singleton;
  }

  KMLUtils._internal();

  /// [photos] are the file names a KMZ actually bundles. When given, the
  /// placemark description becomes HTML referencing `files/<name>`; a photo
  /// missing from that list is left out rather than rendered as a broken
  /// image. A plain .kml passes nothing and keeps the text description.
  static String generateKML(Transect transect, {List<String>? photos}) {
    final bundled = photos?.toSet() ?? const <String>{};
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('kml', nest: () {
      builder.attribute('xmlns', 'http://www.opengis.net/kml/2.2');
      builder.namespaceUri(
          TrackerConfig.current.kmlPrefix, TrackerConfig.current.kmlNamespace);
      builder.element('Document', nest: () {
        builder.element('name', nest: () {
          builder.text('${transect.name}');
        });
        /// Add TimePrimitive
        builder.element('TimeSpan', nest: () {
          builder.element('begin', nest: () {
            builder.text(transect.startDate.toIso8601String());
          });
          builder.element('end', nest: () {
            builder.text(transect.endDate?.toIso8601String() ?? '');
          });
        });
        builder.element('description', nest: () {
          builder.text('Transect ${transect.description}');
        });
        builder.element('Style', nest: () {
          builder.attribute('id', 'redLineRedPoly');
          builder.element('LineStyle', nest: () {
            builder.element('color', nest: () {
              builder.text('ff0051e6');
            });
            builder.element('width', nest: () {
              builder.text('4');
            });
          });
          builder.element('PolyStyle', nest: () {
            builder.element('color', nest: () {
              builder.text('ff9C1E13');
            });
          });
        });

        /// placemark style for markers
        builder.element('Style', nest: () {
          builder.attribute('id', 'markerPlacemark');
          builder.element('IconStyle', nest: () {
           builder.element('Color', nest: () {
              builder.text('ff0051e6');
            });
            builder.element('scale', nest: () {
              builder.text('1.0');
            });
          });
        });

        /// add placemarks from transect.markers
        transect.markers?.forEach((marker) {
          builder.element('Placemark', nest: () {
            builder.attribute('id', 'marker${marker.id}');
            builder.element('styleUrl', nest: () {
              builder.text('#markerPlacemark');
            });
            builder.element('name', nest: () {
              builder.text('Point ${marker.id! + 1}');
            });
            builder.element('description', nest: () {
              if (bundled.isNotEmpty) {
                builder.cdata(_htmlDescription(marker, bundled));
              } else {
                builder.text(marker.summary);
              }
            });

            builder.element('ExtendedData', nest: () {
              /// One <Data> per field: that is what a viewer renders as the
              /// name/value table in the balloon. The description alone is a
              /// one-line summary, and a KML reader has no other way to show
              /// the rest of a record.
              final config = TrackerConfig.current;
              final labels = config.exportColumnLabels();
              final records = marker.records ?? <TrackerRecord>[];
              for (var i = 0; i < records.length; i++) {
                /// a point can hold several records — number them, or the
                /// table would repeat "Species" with no way to tell the
                /// rows apart
                final prefix = records.length > 1 ? '${i + 1}. ' : '';
                final values = config.exportValues(marker, records[i]);
                for (var c = 0; c < labels.length; c++) {
                  _data(builder, '$prefix${labels[c]}', values[c]);
                }
                _data(builder, '$prefix${'csv_header.photos'.tr()}',
                    records[i].photos.join('; '));
              }

              /// The rows above are for humans and lose the enum names and
              /// the exact timestamps; re-import reads this payload instead,
              /// so no field survives only as a label — photo names included,
              /// which no amount of prose could round-trip. Namespaced, so
              /// viewers skip it rather than printing the JSON at the user.
              builder.element(kRecordsDataName,
                  namespaceUri: config.kmlNamespace, nest: () {
                builder.text(jsonEncode({
                  'startDate': marker.startDate?.toIso8601String(),
                  'endDate': marker.endDate?.toIso8601String(),
                  'altitude': marker.altitude,
                  'accuracy': marker.accuracy,
                  'species':
                      marker.records?.map((s) => s.toJson()).toList() ?? [],
                }));
              });
            });
            builder.element('Point', nest: () {
              builder.element('coordinates', nest: () {
                builder.text('${marker.longitude},${marker.latitude}');
              });
            });
          });
        });

        /// add path from transect.points
        builder.element('Placemark', nest: () {
          builder.element('name', nest: () {
            builder.text('Path');
          });
          builder.element('description', nest: () {
            builder.text('Path of transect');
          });
          builder.element('styleUrl', nest: () {
            builder.text('#redLineRedPoly');
          });
          builder.element('LineString', nest: () {
            builder.element('tessellate', nest: () {
              builder.text('1');
            });
            builder.element('coordinates', nest: () {
              builder.text(transect.points
                      ?.map((e) => '${e.longitude},${e.latitude},0')
                      .join(' ') ??
                  '');
            });
          });
        }); // end document
      }); // end kml
    });
    return builder.buildDocument().toXmlString(pretty: true, indent: '\t');
  }

  Transect kmlToTransect(String kml, DateTime fileDate) {
    final document = XmlDocument.parse(kml);
    final transect = Transect();
    final elDocument = document.findAllElements('Document').first;
    transect.name = elDocument.findAllElements('name').first.innerText;
    /// check if element TimeStamp exists
    if (elDocument.findAllElements('TimeStamp').isNotEmpty) {
      final timeStamp = elDocument.findAllElements('TimeStamp').first;
      transect.startDate = DateTime.parse(timeStamp.findAllElements('when').first.innerText);
      transect.endDate = DateTime.parse(timeStamp.findAllElements('when').first.innerText);
    } else {
      /// an imported transect is always finished — endDate must not stay
      /// null, that would mark it as the active one
      transect.startDate = fileDate;
      transect.endDate = fileDate;
    }
    if (elDocument.findAllElements('description').isNotEmpty) {
      transect.description = elDocument
          .findAllElements('description')
          .first
          .innerText;
    }
    final markers = <Placemark>[];
    final points = <Point>[];
    final placemarks = document.findAllElements('Placemark');
    for (final placemark in placemarks) {
      /// Find markers
      final point = placemark.findElements('Point');
      if (point.isNotEmpty) {
        final coordinates = point.first.findElements('coordinates').first.innerText;
        final latLng = _parseCoordinate(coordinates);
        if (latLng == null) continue;
        final record = _readRecords(placemark);

        markers.add(Placemark()
          ..id = markers.length
          ..latitude = latLng.latitude
          ..longitude = latLng.longitude
          ..altitude = finiteOrNull(record?['altitude'] as num?)
          ..accuracy = finiteOrNull(record?['accuracy'] as num?)
          ..startDate = DateTime.tryParse(record?['startDate'] as String? ?? '')
          ..endDate = DateTime.tryParse(record?['endDate'] as String? ?? '')
          ..description = 'Point ${markers.length + 1}'
          ..records = record == null
              ? _recordsFromDescription(placemark)
              : Placemark.recordsFromJson(record['species']));
      }
      /// Find path
      final lineString = placemark.findElements('LineString');
      if (lineString.isNotEmpty) {
        final coord = lineString.first.findElements('coordinates');
        final coordinates = coord.isNotEmpty ? coord.first.innerText : '';
        /// Google Earth separates the tuples with newlines and tabs, not
        /// only spaces; split on any run of whitespace or such a route
        /// imports as empty without a word of complaint
        for (final pointString in coordinates.split(RegExp(r'\s+'))) {
          final latLng = _parseCoordinate(pointString);
          if (latLng == null) continue;
          points.add(Point()
            ..latitude = latLng.latitude
            ..longitude = latLng.longitude);
        }
      }

    }
    transect.markers = markers;
    transect.points = points;
    return transect;
  }

  /// A KML `lon,lat[,alt]` tuple, or null when it is not one the map could
  /// place: `double.parse` accepts "NaN" and the renderer does not.
  static LatLng? _parseCoordinate(String tuple) {
    final parts = tuple.trim().split(',');
    if (parts.length < 2) return null;
    final latitude = finiteOrNull(double.tryParse(parts[1]));
    final longitude = finiteOrNull(double.tryParse(parts[0]));
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  /// Google Earth renders a CDATA description as HTML, so the images show up
  /// in the balloon. `files/` is the KMZ convention for bundled resources.
  static String _htmlDescription(Placemark marker, Set<String> bundled) {
    final sb = StringBuffer();
    for (final record in marker.records ?? <TrackerRecord>[]) {
      sb.write('<p><b>${_escape(record.species)}</b><br/>');
      sb.write(_escape(record.summary));
      sb.write('</p>');
      for (final photo in record.photos.where(bundled.contains)) {
        sb.write(
            '<img src="$kKmzFilesDir/${_escape(photo)}" width="400"/><br/>');
      }
    }
    return sb.toString();
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static void _data(XmlBuilder builder, String name, String value) {
    builder.element('Data', nest: () {
      builder.attribute('name', name);
      builder.element('value', nest: () {
        builder.text(value);
      });
    });
  }

  /// Records written by a tracker app travel in ExtendedData. A KML from
  /// anywhere else — or from before this payload existed — simply has none,
  /// and then the caller falls back to parsing the description.
  ///
  /// Matched by local name: every app writes its own namespace, and a survey
  /// exported by one is still a survey to the other.
  Map<String, dynamic>? _readRecords(XmlElement placemark) {
    for (final el in placemark.descendantElements) {
      if (el.name.local != kRecordsDataName) continue;
      final parsed = _decode(el.innerText);
      if (parsed != null) return parsed;
    }

    /// exports from before the namespaced payload
    for (final data in placemark.findAllElements('Data')) {
      if (data.getAttribute('name') != kRecordsDataName) continue;
      final value = data.findElements('value');
      if (value.isEmpty) continue;
      final parsed = _decode(value.first.innerText);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static Map<String, dynamic>? _decode(String text) {
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (e) {
      log('Could not read KML records payload: ${e.toString()}');
      return null;
    }
  }

  /// A KML written before the payload existed — and any KML from elsewhere —
  /// only has the prose description to offer. Whether that can be read back
  /// into records is the app's call.
  List<TrackerRecord> _recordsFromDescription(XmlElement placemark) {
    final parse = TrackerConfig.current.recordsFromLegacyDescription;
    final desc = placemark.findElements('description');
    if (parse == null || desc.isEmpty) return [];
    return parse(desc.first.innerText);
  }
}
