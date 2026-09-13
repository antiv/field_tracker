import 'package:flutter/material.dart';

/// A whole number with − and + on either side, for counting individuals in
/// the field with a thumb. The controller is the form's, so the field reads
/// back like any other.
class CountField extends StatelessWidget {
  const CountField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.min = 0,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final int min;

  void _step(int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = current + delta;
    if (next < min) return;
    controller.text = next.toString();
  }

  @override
  Widget build(BuildContext context) {
    const box = BoxConstraints(minWidth: 32, minHeight: 32);
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        suffixIconConstraints: box,
        suffixIcon: IconButton(
          icon: const Icon(Icons.add, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: box,
          onPressed: () => _step(1),
        ),
        prefixIconConstraints: box,
        prefixIcon: IconButton(
          icon: const Icon(Icons.remove, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: box,
          onPressed: () => _step(-1),
        ),
      ),
      validator: validator,
      keyboardType: TextInputType.number,
    );
  }
}
