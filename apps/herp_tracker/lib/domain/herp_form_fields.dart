import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/field_options.dart';
import 'herp_record.dart';

/// The herp half of the record form: locality, stage, sex, count and
/// abundance, and the advanced section. Date/time and the GPS values (LAT,
/// LONG, altitude, accuracy) are recorded automatically and deliberately
/// have no fields here — see [HerpRecord.observedAt] and the parent
/// Placemark. The species field, the photos and the buttons are the shell's.
/// Locality is typed by hand but rarely changes within one survey — the last
/// value pre-fills the next record.
const String kLastLocalityKey = 'last_locality';

class HerpFormFields extends StatefulWidget {
  const HerpFormFields({
    super.key,
    this.existing,
    required this.photoStrip,
  });

  final HerpRecord? existing;
  final Widget photoStrip;

  @override
  State<HerpFormFields> createState() => _HerpFormFieldsState();
}

class _HerpFormFieldsState extends RecordFieldsState<HerpFormFields> {
  final TextEditingController _countController =
      TextEditingController(text: '1');
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DevelopmentStage? _stage;
  Sex? _sex;
  AbundanceRange? _abundance;
  DataType? _dataType;
  CollectionMethod? _method;
  HabitatType? _habitat;
  WaterBedType? _waterBed;

  bool _advancedOpen = false;

  @override
  void initState() {
    final species = widget.existing;
    if (species != null) {
      _countController.text = species.count?.toString() ?? '';
      _localityController.text = species.locality ?? '';
      _noteController.text = species.note ?? '';
      _stage = species.stage;
      _sex = species.sex;
      _abundance = species.abundance;
      _dataType = species.dataType;
      _method = species.method;
      _habitat = species.habitat;
      _waterBed = species.waterBed;
      _advancedOpen = species.dataType != null ||
          species.method != null ||
          species.habitat != null ||
          species.waterBed != null ||
          (species.note?.isNotEmpty ?? false);
    } else {
      /// surveys usually stay in one locality for a while — carry the last one over
      _localityController.text =
          DataService().getString(kLastLocalityKey) ?? '';
    }
    super.initState();
  }

  @override
  void dispose() {
    _countController.dispose();
    _localityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  TrackerRecord collect({required String species, TrackerRecord? existing}) {
    final locality = _localityController.text.trim();
    DataService().setString(kLastLocalityKey, locality);
    return HerpRecord()
      ..species = species
      ..observedAt = (existing as HerpRecord?)?.observedAt ?? DateTime.now()
      ..locality = locality.isEmpty ? null : locality
      ..stage = _stage
      ..sex = _sex
      ..count = int.tryParse(_countController.text)
      ..abundance = _abundance
      ..dataType = _dataType
      ..method = _method
      ..habitat = _habitat
      ..waterBed = _waterBed
      ..note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
  }

  /// "Save and new" keeps the context of the survey (locality, habitat,
  /// method) and clears only what describes the individual animal.
  @override
  void reset() {
    setState(() {
      _countController.text = '1';
      _noteController.clear();
      _stage = null;
      _sex = null;
      _abundance = null;
    });
  }

  Map<dynamic, Widget> _labels(List<dynamic> values) => {
        for (final v in values) v: Text(optionLabel(v)),
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _localityController,
          decoration: InputDecoration(
            labelText: 'fields.locality'.tr(),
            prefixIcon: const Icon(Icons.place_outlined),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        OptionPicker<DevelopmentStage>(
          label: 'fields.stage'.tr(),
          options: DevelopmentStage.values,
          value: _stage,
          onChanged: (val) => setState(() => _stage = val),
          labelOf: optionLabel,
          icon: Icons.egg_outlined,
        ),
        const SizedBox(height: 12),

        /// only three values, so radios stay quicker than a dropdown
        EnumRadio(
          key: ValueKey('sex$_sex'),
          enumValues: Sex.values,
          value: _sex,
          onChanged: (val) => setState(() => _sex = val),
          label: 'fields.sex'.tr(),
          icon: Icons.wc_outlined,
          customLabels: _labels(Sex.values),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _countController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'fields.count'.tr(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 16),
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
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
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: OptionPicker<AbundanceRange>(
                label: 'fields.abundance'.tr(),
                options: AbundanceRange.values,
                value: _abundance,
                onChanged: (val) => setState(() => _abundance = val),
                labelOf: optionLabel,
                icon: Icons.functions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        widget.photoStrip,
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('advanced_section'),
            initiallyExpanded: _advancedOpen,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: const Icon(Icons.tune, color: Colors.green),
            title: Text('advanced'.tr()),
            children: [
              OptionPicker<DataType>(
                label: 'fields.data_type'.tr(),
                options: DataType.values,
                value: _dataType,
                onChanged: (val) => setState(() => _dataType = val),
                labelOf: optionLabel,
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 12),
              OptionPicker<CollectionMethod>(
                label: 'fields.method'.tr(),
                options: CollectionMethod.values,
                value: _method,
                onChanged: (val) => setState(() => _method = val),
                labelOf: optionLabel,
                icon: Icons.handyman_outlined,
              ),
              const SizedBox(height: 12),
              OptionPicker<HabitatType>(
                label: 'fields.habitat'.tr(),
                options: HabitatType.values,
                value: _habitat,
                onChanged: (val) => setState(() => _habitat = val),
                labelOf: optionLabel,
                icon: Icons.forest_outlined,
                searchable: true,
              ),
              const SizedBox(height: 12),
              OptionPicker<WaterBedType>(
                label: 'fields.water_bed'.tr(),
                options: WaterBedType.values,
                value: _waterBed,
                onChanged: (val) => setState(() => _waterBed = val),
                labelOf: optionLabel,
                icon: Icons.water_outlined,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
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
            ],
          ),
        ),
      ],
    );
  }
}
