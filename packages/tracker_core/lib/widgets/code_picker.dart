import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A numbered code with a long description — the atlas breeding codes — as
/// a button that opens the list and shows the chosen number, with a clear
/// button next to it once one is chosen.
///
/// [descriptionKey] maps a code to the translation key of its description,
/// e.g. `(code) => 'codes.$code'`.
class CodePicker extends StatelessWidget {
  const CodePicker({
    super.key,
    required this.codes,
    required this.value,
    required this.onChanged,
    required this.descriptionKey,
    this.icon = Icons.explore,
  });

  final List<int> codes;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String Function(int code) descriptionKey;
  final IconData icon;

  Future<void> _pick(BuildContext context) async {
    final code = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('select_atlas_code'.tr()),
        contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: codes.length,
            itemBuilder: (context, index) {
              final code = codes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.green.shade100,
                    child: Text('$code',
                        style: TextStyle(
                            color: Colors.green.shade900, fontSize: 12)),
                  ),
                  title: Text(descriptionKey(code).tr(),
                      style: const TextStyle(fontSize: 14)),
                  onTap: () => Navigator.pop(context, code),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (code != null) onChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: Icon(icon, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value != null
                    ? 'select_code'.tr(args: [value.toString()])
                    : 'select_atlas_code'.tr(),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }
}
