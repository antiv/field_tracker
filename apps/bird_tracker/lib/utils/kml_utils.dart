// Class to create .kml file from a transect, using xml package
import 'dart:convert';
import 'dart:developer';

import 'package:bird_tracker/model/species.dart';
import 'package:bird_tracker/model/transect.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xml/xml.dart';

import '../model/placemark.dart';
import '../model/point.dart';
import 'geo_utils.dart';

/// Name of the ExtendedData entry carrying the machine-readable records.
///
/// A plain `<Data name="records">` is what viewers render as a name/value
/// table — Google My Maps would show the raw JSON to the user. KML 2.2 lets
/// ExtendedData hold arbitrary namespaced content that renderers must ignore,
/// so the payload travels under [kBtNamespace] instead.
const String kRecordsDataName = 'records';

/// Namespace for this app's private ExtendedData payload.
const String kBtNamespace = 'https://antonijevic.rs/bird_tracker';
const String kBtPrefix = 'bt';

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
      builder.namespaceUri(kBtPrefix, kBtNamespace);
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

            /// The description is for humans (Google Earth) and, for an older
            /// export, all a re-import had to go on. This payload carries the
            /// records losslessly instead — photo names included, which no
            /// amount of prose could round-trip. Namespaced, so viewers skip
            /// it rather than printing the JSON at the user.
            builder.element('ExtendedData', nest: () {
              builder.element(kRecordsDataName, namespaceUri: kBtNamespace,
                  nest: () {
                builder.text(jsonEncode({
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

        /// A KML written before the payload existed — and any KML from
        /// elsewhere — still only has the prose description to offer.
        final desc = placemark.findElements('description');
        final species = desc.isNotEmpty ? desc.first.innerText : null;

        markers.add(Placemark()
          ..id = markers.length
          ..latitude = latLng.latitude
          ..longitude = latLng.longitude
          ..startDate = DateTime.tryParse(record?['startDate'] as String? ?? '')
          ..endDate = DateTime.tryParse(record?['endDate'] as String? ?? '')
          ..description = 'Point ${markers.length + 1}'
          ..species = record == null
              ? getSpeciesFromDescription(species)
              : (record['species'] as List<dynamic>?)
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
  /// else — or from before this payload existed — simply has none, and then
  /// the caller falls back to parsing the description.
  Map<String, dynamic>? _readRecords(XmlElement placemark) {
    for (final el in placemark.findAllElements(kRecordsDataName,
        namespaceUri: kBtNamespace)) {
      try {
        return Map<String, dynamic>.from(jsonDecode(el.innerText) as Map);
      } catch (e) {
        log('Could not read KML records payload: ${e.toString()}');
      }
    }
    return null;
  }

  List<Species>? getSpeciesFromDescription(String? description) {
    if (description == null) {
      return null;
    }
    final species = description.split(';');
    if (species.isEmpty) {
      return null;
    } else {
      /// return Species().listFromString(species) and remove nulls
      return Species().listFromString(species)?.toList();
    }
  }
}
