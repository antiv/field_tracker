// Class to create .kml file from a transect, using xml package
import 'dart:convert';
import 'dart:developer';

import 'package:easy_localization/easy_localization.dart';
import 'package:herp_tracker/model/species.dart';
import 'package:herp_tracker/model/transect.dart';
import 'package:xml/xml.dart';

import '../model/placemark.dart';
import '../model/point.dart';

/// Name of the ExtendedData entry carrying the machine-readable records.
///
/// The payload used to be a plain `<Data name="records">`, which viewers
/// render as a name/value table — Google My Maps showed the raw JSON to the
/// user. KML 2.2 lets ExtendedData hold arbitrary namespaced content that
/// renderers must ignore, so it now travels under [kHerpNamespace] instead.
/// The old form is still read, or every KML already shared with a colleague
/// would stop importing.
const String kRecordsDataName = 'records';

/// Namespace for this app's private ExtendedData payload.
const String kHerpNamespace = 'https://antonijevic.rs/herp_tracker';
const String kHerpPrefix = 'herp';

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
      builder.namespaceUri(kHerpPrefix, kHerpNamespace);
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
                builder.text(marker.speciesString);
              }
            });

            builder.element('ExtendedData', nest: () {
              /// One <Data> per field: that is what a viewer renders as the
              /// name/value table in the balloon. The description alone is a
              /// one-line summary, and a KML reader has no other way to show
              /// the rest of a record.
              final records = marker.species ?? <Species>[];
              for (var i = 0; i < records.length; i++) {
                /// a point can hold several findings — number them, or the
                /// table would repeat "Species" with no way to tell the
                /// rows apart
                final prefix = records.length > 1 ? '${i + 1}. ' : '';
                final values = marker.exportValues(records[i]);
                for (var c = 0; c < kRecordColumnKeys.length; c++) {
                  builder.element('Data', nest: () {
                    builder.attribute(
                        'name', '$prefix${kRecordColumnKeys[c].tr()}');
                    builder.element('value', nest: () {
                      builder.text(values[c]);
                    });
                  });
                }
                builder.element('Data', nest: () {
                  builder.attribute('name', '$prefix${'csv_header.photos'.tr()}');
                  builder.element('value', nest: () {
                    builder.text(records[i].photos.join('; '));
                  });
                });
              }

              /// The rows above are for humans and lose the enum names and
              /// the exact timestamps; re-import reads this payload instead,
              /// so no field survives only as a label. Namespaced, so viewers
              /// skip it rather than printing the JSON at the user.
              builder.element(kRecordsDataName, namespaceUri: kHerpNamespace,
                  nest: () {
                builder.text(jsonEncode({
                  'altitude': marker.altitude,
                  'accuracy': marker.accuracy,
                  'startDate': marker.startDate?.toIso8601String(),
                  'endDate': marker.endDate?.toIso8601String(),
                  'species':
                      marker.species?.map((s) => s.toJson()).toList() ?? [],
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
      transect.startDate =
          DateTime.parse(timeStamp.findAllElements('when').first.innerText);
      transect.endDate =
          DateTime.parse(timeStamp.findAllElements('when').first.innerText);
    } else {
      /// an imported transect is always finished — endDate must not stay
      /// null, that would mark it as the active one
      transect.startDate = fileDate;
      transect.endDate = fileDate;
    }
    if (elDocument.findAllElements('description').isNotEmpty) {
      transect.description =
          elDocument.findAllElements('description').first.innerText;
    }
    final markers = <Placemark>[];
    final points = <Point>[];
    final placemarks = document.findAllElements('Placemark');
    for (final placemark in placemarks) {
      /// Find markers
      final point = placemark.findElements('Point');
      if (point.isNotEmpty) {
        final coordinates =
            point.first.findElements('coordinates').first.innerText;
        final pointString = coordinates.split(',');
        final record = _readRecords(placemark);
        markers.add(Placemark()
          ..id = markers.length
          ..latitude = double.parse(pointString[1])
          ..longitude = double.parse(pointString[0])
          ..altitude = (record?['altitude'] as num?)?.toDouble()
          ..accuracy = (record?['accuracy'] as num?)?.toDouble()
          ..startDate = DateTime.tryParse(record?['startDate'] as String? ?? '')
          ..endDate = DateTime.tryParse(record?['endDate'] as String? ?? '')
          ..description = 'Point ${markers.length + 1}'
          ..species = (record?['species'] as List<dynamic>?)
                  ?.map((s) =>
                      Species.fromJson(Map<String, dynamic>.from(s as Map)))
                  .toList() ??
              []);
      }

      /// Find path
      final lineString = placemark.findElements('LineString');
      if (lineString.isNotEmpty) {
        final coord = lineString.first.findElements('coordinates');
        final coordinates = coord.isNotEmpty ? coord.first.innerText : '';
        final pointsString = coordinates.split(' ');
        for (final pointString in pointsString) {
          final point = pointString.trim().split(',');
          if (point.length < 2) {
            continue;
          }
          points.add(Point()
            ..latitude = double.parse(point[1])
            ..longitude = double.parse(point[0]));
        }
      }
    }
    transect.markers = markers;
    transect.points = points;
    return transect;
  }

  /// Google Earth renders a CDATA description as HTML, so the images show up
  /// in the balloon. `files/` is the KMZ convention for bundled resources.
  static String _htmlDescription(Placemark marker, Set<String> bundled) {
    final sb = StringBuffer();
    for (final record in marker.species ?? <Species>[]) {
      sb.write('<p><b>${_escape(record.species)}</b><br/>');
      sb.write(_escape(record.speciesString));
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

  /// Records written by this app travel in ExtendedData. A KML from anywhere
  /// else simply has none — then only the geometry is imported.
  Map<String, dynamic>? _readRecords(XmlElement placemark) {
    for (final el
        in placemark.findAllElements(kRecordsDataName, namespaceUri: kHerpNamespace)) {
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

  Map<String, dynamic>? _decode(String payload) {
    try {
      return Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (e) {
      log('Could not read KML records payload: ${e.toString()}');
      return null;
    }
  }
}
