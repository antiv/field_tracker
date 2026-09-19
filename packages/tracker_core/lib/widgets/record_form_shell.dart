import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../config/tracker_config.dart';
import '../service/media_service.dart';
import 'bt_autocomplete.dart';
import 'photo_strip.dart';

/// The record form's shared half: species autocomplete on top, the app's
/// fields in the middle, Cancel / Save and new / Save at the bottom — plus
/// the photos, whose files need care the app should not have to repeat.
///
/// Photos hit the disk the moment they are taken, before the record exists.
/// [_committed] is what the record being edited already owns: anything in
/// [_photos] beyond it was added and is dropped if the form is cancelled, and
/// anything in it that a save no longer lists is deleted on that save.
class RecordFormShell extends StatefulWidget {
  const RecordFormShell({super.key, this.onSaved, this.existing});

  /// Called with the record and whether the dialog is about to close.
  final void Function(TrackerRecord record, bool close)? onSaved;

  /// The record being edited; null for a new one.
  final TrackerRecord? existing;

  @override
  State<RecordFormShell> createState() => _RecordFormShellState();
}

class _RecordFormShellState extends State<RecordFormShell> {
  final _formKey = GlobalKey<FormState>();
  final _fieldsKey = GlobalKey<RecordFieldsState>();
  final TextEditingController _speciesController = TextEditingController();
  final FocusNode _speciesFocusNode = FocusNode();

  List<String> _photos = [];
  Set<String> _committed = {};

  bool get _isEdit => widget.existing != null;

  bool get _hasSpeciesField => TrackerConfig.current.speciesCatalog != null;

  @override
  void initState() {
    final existing = widget.existing;
    if (existing != null) {
      _speciesController.text = existing.species;
      _photos = List.of(existing.photos);
      _committed.addAll(_photos);
    } else if (_hasSpeciesField) {
      _speciesFocusNode.requestFocus();
    }
    super.initState();
  }

  @override
  void dispose() {
    /// covers both Cancel and the close button in showFullScreenDialog's
    /// AppBar — the gallery copy stays, the way a camera app behaves
    final orphans = _photos.where((n) => !_committed.contains(n)).toList();
    if (orphans.isNotEmpty) {
      MediaService().delete(orphans);
    }
    _speciesController.dispose();
    _speciesFocusNode.dispose();
    super.dispose();
  }

  bool _save(bool close) {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_valid_data'.tr())),
      );
      return false;
    }
    final record = _fieldsKey.currentState!.collect(
      species: _speciesController.text.trim(),
      existing: widget.existing,
    )..photos = List.of(_photos);

    /// the save makes the removals permanent, so their files can go
    MediaService().delete(_committed.difference(_photos.toSet()));
    _committed = _photos.toSet();

    widget.onSaved?.call(record, close);
    return true;
  }

  /// "Save and new": the record just saved owns its photos now; the next one
  /// starts with none, and must not be able to delete the previous one's
  /// files.
  void _clear() {
    setState(() {
      _speciesController.clear();
      if (_hasSpeciesField) _speciesFocusNode.requestFocus();
      _fieldsKey.currentState?.reset();
      _committed = {};
      _photos = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = TrackerConfig.current;
    return SingleChildScrollView(
      key: const ValueKey('species_form'),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasSpeciesField) ...[
                BtAutocomplete(
                  speciesFocusNode: _speciesFocusNode,
                  speciesController: _speciesController,
                  kOptions: config.speciesCatalog!,
                ),
                const SizedBox(height: 12),
              ],
              config.recordFields(
                key: _fieldsKey,
                existing: widget.existing,
                photoStrip: PhotoStrip(
                  names: _photos,
                  onChanged: (names) => setState(() => _photos = names),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('cancel'.tr()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!_isEdit && !config.singleRecordPerPoint) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_save(false)) {
                            _clear();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade900,
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('save_and_new'.tr()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_save(true)) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('save'.tr()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
