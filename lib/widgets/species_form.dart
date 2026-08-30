import 'package:herp_tracker/configuration/field_options.dart';
import 'package:herp_tracker/configuration/species.dart';
import 'package:herp_tracker/model/species.dart';
import 'package:herp_tracker/service/data_service.dart';
import 'package:herp_tracker/service/media_service.dart';
import 'package:herp_tracker/widgets/enum_radio.dart';
import 'package:herp_tracker/widgets/option_picker.dart';
import 'package:herp_tracker/widgets/photo_strip.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'bt_autocomplete.dart';

/// Form for one observation record. Date/time and the GPS values (LAT, LONG,
/// altitude, accuracy) are recorded automatically and deliberately have no
/// fields here — see [Species.observedAt] and the parent Placemark.
class SpeciesForm extends StatefulWidget {
  const SpeciesForm({super.key, this.onSaved, this.species});

  final Function? onSaved;
  final Species? species;

  @override
  State<SpeciesForm> createState() => _SpeciesFormState();
}

class _SpeciesFormState extends State<SpeciesForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _speciesController = TextEditingController();
  final TextEditingController _countController =
      TextEditingController(text: '1');
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _speciesFocusNode = FocusNode();

  DevelopmentStage? _stage;
  Sex? _sex;
  AbundanceRange? _abundance;
  DataType? _dataType;
  CollectionMethod? _method;
  HabitatType? _habitat;
  WaterBedType? _waterBed;

  bool _isEdit = false;
  bool _advancedOpen = false;

  /// Photos hit the disk the moment they are taken, before the record exists.
  /// [_committed] is what the record being edited already owns: anything in
  /// [_photos] beyond it was added and is dropped if the form is cancelled,
  /// and anything in it that a save no longer lists is deleted on that save.
  List<String> _photos = [];
  Set<String> _committed = {};

  @override
  void initState() {
    final species = widget.species;
    if (species != null) {
      _isEdit = true;
      _speciesController.text = species.species;
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
      _photos = List.of(species.photos);
      _committed.addAll(_photos);
      _advancedOpen = species.dataType != null ||
          species.method != null ||
          species.habitat != null ||
          species.waterBed != null ||
          (species.note?.isNotEmpty ?? false);
    } else {
      /// surveys usually stay in one locality for a while — carry the last one over
      _localityController.text =
          DataService().getLastLocalityPreference() ?? '';
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
    _countController.dispose();
    _localityController.dispose();
    _noteController.dispose();
    _speciesFocusNode.dispose();
    super.dispose();
  }

  bool _save(bool close) {
    if (_formKey.currentState!.validate()) {
      final locality = _localityController.text.trim();
      final species = Species()
        ..species = _speciesController.text.trim()
        ..observedAt = widget.species?.observedAt ?? DateTime.now()
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
            : _noteController.text.trim()
        ..photos = List.of(_photos);

      /// the save makes the removals permanent, so their files can go
      MediaService().delete(_committed.difference(_photos.toSet()));
      _committed = _photos.toSet();

      DataService().setLastLocalityPreference(locality);

      if (widget.onSaved != null) {
        widget.onSaved!(species, close);
      }
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('enter_valid_data'.tr()),
        ),
      );
      return false;
    }
  }

  /// "Save and new" keeps the context of the survey (locality, habitat, method)
  /// and clears only what describes the individual animal.
  void _clear() {
    setState(() {
      _speciesController.clear();
      _countController.text = '1';
      _speciesFocusNode.requestFocus();
      _noteController.clear();
      _stage = null;
      _sex = null;
      _abundance = null;

      /// the record just saved owns its photos now; the next one starts with
      /// none, and must not be able to delete the previous one's files
      _committed = {};
      _photos = [];
    });
  }

  Map<dynamic, Widget> _labels(List<dynamic> values) => {
        for (final v in values) v: Text(optionLabel(v)),
      };

  @override
  Widget build(BuildContext context) {
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
                BtAutocomplete(
                  speciesFocusNode: _speciesFocusNode,
                  speciesController: _speciesController,
                  kOptions: kSpecies,
                ),
                const SizedBox(height: 12),
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
                        icon: Icons.functions,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PhotoStrip(
                  names: _photos,
                  onChanged: (names) => setState(() => _photos = names),
                ),
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
                        icon: Icons.category_outlined,
                      ),
                      const SizedBox(height: 12),
                      OptionPicker<CollectionMethod>(
                        label: 'fields.method'.tr(),
                        options: CollectionMethod.values,
                        value: _method,
                        onChanged: (val) => setState(() => _method = val),
                        icon: Icons.handyman_outlined,
                      ),
                      const SizedBox(height: 12),
                      OptionPicker<HabitatType>(
                        label: 'fields.habitat'.tr(),
                        options: HabitatType.values,
                        value: _habitat,
                        onChanged: (val) => setState(() => _habitat = val),
                        icon: Icons.forest_outlined,
                        searchable: true,
                      ),
                      const SizedBox(height: 12),
                      OptionPicker<WaterBedType>(
                        label: 'fields.water_bed'.tr(),
                        options: WaterBedType.values,
                        value: _waterBed,
                        onChanged: (val) => setState(() => _waterBed = val),
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
                    if (!_isEdit)
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
                    if (!_isEdit) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_save(false)) {
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
            )),
      ),
    );
  }
}
