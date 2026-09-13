import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/codes.dart';
import '../widgets/block_enum_radio.dart';
import '../widgets/world_side_picker.dart';
import 'bird_record.dart';

/// The bird half of the record form: count, atlas code, direction and
/// stratification, behaviour notes. The species field, the photos and the
/// buttons are the shell's.
class BirdFormFields extends StatefulWidget {
  const BirdFormFields({
    super.key,
    this.existing,
    required this.photoStrip,
  });

  final BirdRecord? existing;
  final Widget photoStrip;

  @override
  State<BirdFormFields> createState() => _BirdFormFieldsState();
}

class _BirdFormFieldsState extends RecordFieldsState<BirdFormFields> {
  final TextEditingController _countController =
      TextEditingController(text: '1');
  final TextEditingController _descriptionController = TextEditingController();

  Direction? _direction;
  Stratification? _stratification = Stratification.d;
  int? _code;

  @override
  void initState() {
    final existing = widget.existing;
    if (existing != null) {
      _countController.text = existing.count.toString();
      _descriptionController.text = existing.description ?? '';
      _direction = existing.direction;
      _stratification = existing.stratification ?? Stratification.d;
      _code = existing.code;
    }
    super.initState();
  }

  @override
  void dispose() {
    _countController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  TrackerRecord collect({required String species, TrackerRecord? existing}) {
    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    return BirdRecord()
      ..species = species
      ..code = _code
      ..count = int.tryParse(_countController.text) ?? 1
      ..time = (existing as BirdRecord?)?.time ?? now
      ..direction = _direction
      ..stratification = _stratification
      ..description = _descriptionController.text;
  }

  @override
  void reset() {
    setState(() {
      _countController.text = '1';
      _descriptionController.clear();
      _code = null;
      _direction = null;
      _stratification = Stratification.d;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('select_atlas_code'.tr()),
                      contentPadding:
                          const EdgeInsets.fromLTRB(8, 20, 8, 8),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: kCodes.keys.length,
                          itemBuilder: (context, index) {
                            final code = kCodes.keys.elementAt(index);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      Colors.green.shade100,
                                  child: Text('$code',
                                      style: TextStyle(
                                          color: Colors.green.shade900,
                                          fontSize: 12)),
                                ),
                                title: Text('codes.$code'.tr(),
                                    style:
                                        const TextStyle(fontSize: 14)),
                                onTap: () {
                                  setState(() => _code = code);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.explore, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _code != null
                        ? 'select_code'.tr(args: [_code.toString()])
                        : 'select_atlas_code'.tr(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_code != null)
              IconButton(
                onPressed: () => setState(() => _code = null),
                icon: const Icon(Icons.clear,
                    color: Colors.grey, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _countController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'count'.tr(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 16),
                  suffixIconConstraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: () {
                      final current =
                          int.tryParse(_countController.text) ?? 0;
                      _countController.text = (current + 1).toString();
                    },
                  ),
                  prefixIconConstraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: () {
                      final current =
                          int.tryParse(_countController.text) ?? 0;
                      if (current > 0) {
                        _countController.text =
                            (current - 1).toString();
                      }
                    },
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'enter_valid_data'.tr()
                    : null,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            WorldSidePicker(
              key: ValueKey('dir$_direction'),
              selectedSide: _direction,
              onChanged: (val) => setState(() {
                _direction = val;
              }),
              color: Colors.green.shade700,
              radius: 80,
              label: 'direction_label'.tr(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: BlockEnumRadio(
                key: ValueKey('stratification$_stratification'),
                enumValues: Stratification.values,
                value: _stratification,
                onChanged: (val) => setState(() {
                  _stratification = val;
                }),
                label: 'strat_label'.tr(),
                customLabels: const {
                  Stratification.g: Icon(Icons.vertical_align_top),
                  Stratification.s: Icon(Icons.vertical_align_center),
                  Stratification.d: Icon(Icons.vertical_align_bottom),
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'behavior'.tr(),
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
