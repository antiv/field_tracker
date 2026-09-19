import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/codes.dart';
import '../configuration/options.dart';
import 'nest_record.dart';

/// The nest half of the record form: position, state, number of young, the
/// atlas code, place and municipality, a note. The photos and the buttons
/// are the shell's; there is no species field — every record is a stork.
class NestFormFields extends StatefulWidget {
  const NestFormFields({
    super.key,
    this.existing,
    required this.photoStrip,
  });

  final NestRecord? existing;
  final Widget photoStrip;

  @override
  State<NestFormFields> createState() => _NestFormFieldsState();
}

class _NestFormFieldsState extends RecordFieldsState<NestFormFields> {
  final TextEditingController _countController =
      TextEditingController(text: '0');
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _municipalityController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  NestPosition? _position;
  NestState? _state;
  int? _code;

  @override
  void initState() {
    final existing = widget.existing;
    if (existing != null) {
      _countController.text = existing.count.toString();
      _placeController.text = existing.place ?? '';
      _municipalityController.text = existing.municipality ?? '';
      _descriptionController.text = existing.description ?? '';
      _position = existing.position;
      _state = existing.state;
      _code = existing.code;
    }
    super.initState();
  }

  @override
  void dispose() {
    _countController.dispose();
    _placeController.dispose();
    _municipalityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  TrackerRecord collect({required String species, TrackerRecord? existing}) {
    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    return NestRecord()
      ..time = (existing as NestRecord?)?.time ?? now
      ..count = int.tryParse(_countController.text) ?? 0
      ..code = _code
      ..position = _position
      ..state = _state
      ..place = _trimmed(_placeController)
      ..municipality = _trimmed(_municipalityController)
      ..description = _trimmed(_descriptionController);
  }

  String? _trimmed(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// One nest per point, so this only runs if the shell ever offers "Save
  /// and new"; the village stays, the nest is new.
  @override
  void reset() {
    setState(() {
      _countController.text = '0';
      _descriptionController.clear();
      _position = null;
      _state = null;
      _code = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OptionPicker<NestPosition>(
          label: 'fields.position'.tr(),
          options: NestPosition.values,
          value: _position,
          onChanged: (val) => setState(() => _position = val),
          labelOf: optionLabel,
          icon: Icons.location_city_outlined,
        ),
        const SizedBox(height: 12),
        OptionPicker<NestState>(
          label: 'fields.state'.tr(),
          options: NestState.values,
          value: _state,
          onChanged: (val) => setState(() => _state = val),
          labelOf: optionLabel,
          icon: Icons.egg_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: CodePicker(
                codes: kCodes.keys.toList(),
                value: _code,
                onChanged: (code) => setState(() => _code = code),
                descriptionKey: (code) => 'codes.$code',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: CountField(
                controller: _countController,
                label: 'fields.young'.tr(),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'enter_valid_data'.tr()
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _placeController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'fields.place'.tr(),
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _municipalityController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'fields.municipality'.tr(),
            prefixIcon: const Icon(Icons.map_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'fields.note'.tr(),
            prefixIcon: const Icon(Icons.notes),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          minLines: 1,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 12),
        widget.photoStrip,
      ],
    );
  }
}
