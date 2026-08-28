import 'package:flutter/material.dart';

/// Compact single-choice row for short option lists (Sex has three values).
///
/// Styled as an [InputDecorator] so it lines up with the dropdowns of
/// [OptionPicker]; the whole control is one form-field-high line instead of a
/// tall bordered block.
class EnumRadio extends StatelessWidget {
  const EnumRadio({
    super.key,
    this.enumValues,
    this.value,
    this.onChanged,
    this.customLabels,
    this.label,
    this.icon,
  });

  final List<dynamic>? enumValues;
  final dynamic value;
  final Function(dynamic)? onChanged;
  final Map<dynamic, Widget>? customLabels;
  final String? label;
  final IconData? icon;

  Widget _labelFor(dynamic e) =>
      customLabels?[e] ?? Text(e.toString().split('.').last);

  @override
  Widget build(BuildContext context) {
    final values = enumValues ?? const [];
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(8, 10, 4, 6),
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () => onChanged?.call(null),
              )
            : null,
      ),
      child: RadioGroup<dynamic>(
        groupValue: value,
        onChanged: (dynamic val) => onChanged?.call(val),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: values
              .map((e) => InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onChanged?.call(e),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<dynamic>(
                          value: e,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _labelFor(e),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
