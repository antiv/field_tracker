import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../configuration/field_options.dart';

/// Single-choice field for the enumerated record fields. Values are enum
/// constants, labels come from [optionLabel] so they follow the app language.
///
/// Long lists (habitat has 36 values) open a searchable dialog instead of a
/// dropdown that would need endless scrolling.
class OptionPicker<T> extends StatelessWidget {
  const OptionPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
    this.searchable = false,
  });

  final String label;
  final List<T> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool searchable;

  @override
  Widget build(BuildContext context) {
    if (searchable) {
      return _SearchableField<T>(
        label: label,
        options: options,
        value: value,
        onChanged: onChanged,
        icon: icon,
      );
    }
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      items: options
          .map((o) => DropdownMenuItem<T>(
                value: o,
                child: Text(optionLabel(o), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SearchableField<T> extends StatelessWidget {
  const _SearchableField({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final List<T> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final IconData? icon;

  Future<void> _pick(BuildContext context) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) =>
          _OptionSearchDialog<T>(title: label, options: options),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.search, size: 18, color: Colors.grey),
      ),
      child: InkWell(
        onTap: () => _pick(context),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            value != null ? optionLabel(value) : '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _OptionSearchDialog<T> extends StatefulWidget {
  const _OptionSearchDialog({required this.title, required this.options});

  final String title;
  final List<T> options;

  @override
  State<_OptionSearchDialog<T>> createState() => _OptionSearchDialogState<T>();
}

class _OptionSearchDialogState<T> extends State<_OptionSearchDialog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where(
            (o) => optionLabel(o).toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'search'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(optionLabel(filtered[index])),
                  onTap: () => Navigator.pop(context, filtered[index]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
      ],
    );
  }
}
