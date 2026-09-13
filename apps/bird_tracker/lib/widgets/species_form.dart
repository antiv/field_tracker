import 'package:bird_tracker/configuration/codes.dart';
import 'package:bird_tracker/configuration/species.dart';
import 'package:bird_tracker/model/species.dart';
import 'package:bird_tracker/service/media_service.dart';
import 'package:bird_tracker/widgets/enum_radio.dart';
import 'package:bird_tracker/widgets/photo_strip.dart';
import 'package:bird_tracker/widgets/world_side_picker.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'bt_autocomplete.dart';

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
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _speciesFocusNode = FocusNode();

  Direction? _direction;
  Stratification? _stratification = Stratification.d;

  int? _code;
  bool _isEdit = false;

  /// Photos hit the disk the moment they are taken, before the record exists.
  /// [_committed] is what the record being edited already owns: anything in
  /// [_photos] beyond it was added and is dropped if the form is cancelled,
  /// and anything in it that a save no longer lists is deleted on that save.
  List<String> _photos = [];
  Set<String> _committed = {};

  @override
  void initState() {
    // _spicesFocusNode.requestFocus();
    if (widget.species != null) {
      _isEdit = true;
      _speciesController.text = widget.species?.species ?? '';
      _countController.text = widget.species!.count.toString();
      _descriptionController.text = widget.species!.description ?? '';
      _direction = widget.species?.direction;
      _stratification = widget.species?.stratification ?? Stratification.d;
      _code = widget.species?.code;
      _photos = List.of(widget.species!.photos);
      _committed.addAll(_photos);
    } else {
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
    _speciesFocusNode.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _save(bool close) {
    if (_formKey.currentState!.validate()) {
      final species = Species()
        ..species = _speciesController.text
        ..code = _code
        ..count = int.tryParse(_countController.text) ?? 1
        ..time = _isEdit
            ? (widget.species?.time ??
                DateFormat('HH:mm:ss').format(DateTime.now()))
            : DateFormat('HH:mm:ss').format(DateTime.now())
        ..direction = _direction
        ..stratification = _stratification
        ..description = _descriptionController.text
        ..photos = List.of(_photos);

      /// the save makes the removals permanent, so their files can go
      MediaService().delete(_committed.difference(_photos.toSet()));
      _committed = _photos.toSet();

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

  void _clear() {
    setState(() {
      _speciesController.clear();
      _countController.text = '1';
      _speciesFocusNode.requestFocus();
      _descriptionController.clear();
      _code = null;
      _direction = null;
      _stratification = Stratification.d;

      /// the record just saved owns its photos now; the next one starts with
      /// none, and must not be able to delete the previous one's files
      _committed = {};
      _photos = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Create form to add species data
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
                      child: EnumRadio(
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
                PhotoStrip(
                  names: _photos,
                  onChanged: (names) => setState(() => _photos = names),
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
