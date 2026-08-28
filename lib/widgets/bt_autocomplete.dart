import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class BtAutocomplete extends StatelessWidget {
  const BtAutocomplete({
    super.key,
    required this.speciesFocusNode,
    required this.speciesController,
    required this.kOptions,
  }) : _btFocusNode = speciesFocusNode, _btController = speciesController;

  final FocusNode _btFocusNode;
  final TextEditingController _btController;
  final TextEditingController speciesController;
  final FocusNode speciesFocusNode;
  final List<String> kOptions;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete(
      key: const ValueKey('autocomplete_text_field'),
      focusNode: _btFocusNode,
      textEditingController: _btController,
      fieldViewBuilder: (BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onFieldSubmitted: (String value) {
            onFieldSubmitted();
          },
          decoration: InputDecoration(
            labelText: 'species_label'.tr(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: InkWell(
              child: const Icon(Icons.clear),
              onTap: () {
                _btController.clear();
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'please_enter_value'.tr();
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                        _btFocusNode.unfocus();
                      },
                      child: ListTile(
                        dense: true,
                        title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('species.$option'.tr(), style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        } else {
          return kOptions.where((String option) {
            final translated = 'species.$option'.tr().toLowerCase();
            final original = option.toLowerCase();
            final search = textEditingValue.text.toLowerCase();
            return original.contains(search) || translated.contains(search);
          });
        }
      },
    );
  }
}