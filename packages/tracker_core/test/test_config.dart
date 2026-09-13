import 'package:flutter/material.dart';
import 'package:tracker_core/tracker_core.dart';

/// The smallest record an app could define: a species, a note, photos.
class TestRecord implements TrackerRecord {
  TestRecord({required this.species, this.note, List<String>? photos})
      : photos = photos ?? [];

  @override
  String species;
  String? note;

  @override
  List<String> photos;

  @override
  Map<String, dynamic> toJson() =>
      {'species': species, 'note': note, 'photos': photos};

  static TestRecord fromJson(Map<String, dynamic> json) => TestRecord(
        species: json['species'] as String,
        note: json['note'] as String?,
        photos: (json['photos'] as List<dynamic>?)?.cast<String>().toList(),
      );

  @override
  String get summary => '$species: ${note ?? ''}';

  @override
  String get subtitle => note ?? '';
}

class _TestFields extends StatefulWidget {
  const _TestFields({super.key, this.existing, required this.photoStrip});

  final TestRecord? existing;
  final Widget photoStrip;

  @override
  State<_TestFields> createState() => _TestFieldsState();
}

class _TestFieldsState extends RecordFieldsState<_TestFields> {
  final _note = TextEditingController();

  @override
  void initState() {
    _note.text = widget.existing?.note ?? '';
    super.initState();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  TrackerRecord collect({required String species, TrackerRecord? existing}) =>
      TestRecord(species: species, note: _note.text);

  @override
  void reset() => _note.clear();

  @override
  Widget build(BuildContext context) => Column(children: [
        TextFormField(
            key: const ValueKey('note'),
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note')),
        widget.photoStrip,
      ]);
}

TrackerConfig testConfig({
  bool singleRecordPerPoint = false,
  List<String>? catalog = const ['Parus major', 'Sitta europaea'],
}) =>
    TrackerConfig(
      appTitle: 'Test Tracker',
      logoAsset: 'assets/icons/logo.svg',
      galleryAlbum: 'Test Tracker',
      photoPrefix: 'TT',
      dbName: 'test_tracker.db',
      backupBaseName: 'test_tracker_backup',
      kmlNamespace: 'https://antonijevic.rs/test_tracker',
      kmlPrefix: 'tt',
      androidPackage: 'rs.antonijevic.test_tracker',
      speciesCatalog: catalog,
      singleRecordPerPoint: singleRecordPerPoint,
      recordFromJson: TestRecord.fromJson,
      exportColumnLabels: () => const ['Species', 'Note'],
      exportValues: (point, record) =>
          [record.species, (record as TestRecord).note ?? ''],
      recordFields: ({required key, existing, required photoStrip}) =>
          _TestFields(
              key: key,
              existing: existing as TestRecord?,
              photoStrip: photoStrip),
    );
