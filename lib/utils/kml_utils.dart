// Class to create .kml file from a transect, using xml package
import 'dart:convert';
import 'dart:developer';

import 'package:herp_tracker/model/species.dart';
import 'package:herp_tracker/model/transect.dart';
import 'package:xml/xml.dart';

import '../model/placemark.dart';
import '../model/point.dart';

/// Name of the ExtendedData entry carrying the machine-readable records.
const String kRecordsDataName = 'records';

class KMLUtils {
  static final KMLUtils _singleton = KMLUtils._internal();

  factory KMLUtils() {
    return _singleton;
  }

  KMLUtils._internal();

  static String generateKML(Transect transect) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('kml', nest: () {
      builder.attribute('xmlns', 'http://www.opengis.net/kml/2.2');
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
              builder.text(marker.speciesString);
            });

            /// The description is for humans (Google Earth); re-import reads
            /// this payload instead, so no field survives only as prose.
            builder.element('ExtendedData', nest: () {
              builder.element('Data', nest: () {
                builder.attribute('name', kRecordsDataName);
                builder.element('value', nest: () {
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

  /// Records written by this app travel in ExtendedData. A KML from anywhere
  /// else simply has none — then only the geometry is imported.
  Map<String, dynamic>? _readRecords(XmlElement placemark) {
    for (final data in placemark.findAllElements('Data')) {
      if (data.getAttribute('name') != kRecordsDataName) continue;
      final value = data.findElements('value');
      if (value.isEmpty) continue;
      try {
        return Map<String, dynamic>.from(
            jsonDecode(value.first.innerText) as Map);
      } catch (e) {
        log('Could not read KML records payload: ${e.toString()}');
      }
    }
    return null;
  }
}
