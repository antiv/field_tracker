import 'dart:io';

import 'package:herp_tracker/service/data_service.dart';
import 'package:herp_tracker/service/sembast_service.dart';
import 'package:herp_tracker/utils/kml_utils.dart';
import 'package:context_holder/context_holder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';

import '../model/transect.dart';

/// EG.
// showBottomModal(context, Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ListTile(
//           leading: const Icon(Icons.edit),
//           title: const Text('Edit'),
//           onTap: () {
//             Navigator.of(context).pop();
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.delete),
//           title: const Text('Delete'),
//           onTap: () {
//             Navigator.of(context).pop();
//           },
//         ),
//       ],
//     ));
void showBottomModal(Widget widget) {
  showModalBottomSheet(
    context: ContextHolder.currentContext,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    showDragHandle: true,
    builder: (BuildContext context) {
      return widget;
    },
  );
}

void showDialogBox(Widget widget) {
  showDialog(
    context: ContextHolder.currentContext,
    builder: (BuildContext context) {
      return widget;
    },
  );
}

void showAlertDialog(Widget content, List<Widget> actions) {
  showDialogBox(AlertDialog(
    content: content,
    actions: actions,
  ));
}

void showYesNoDialog(
  VoidCallback yesFunction,
  VoidCallback noFunction, {
  String? title,
  String? yesText,
  String? noText,
}) {
  showAlertDialog(
    Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(title ?? 'are_you_sure'.tr(), style: const TextStyle(fontSize: 16)),
    ),
    [
      OutlinedButton(
        onPressed: () {
          Navigator.of(ContextHolder.currentContext).pop();
          noFunction();
        },
        child: Text(noText ?? 'no'.tr()),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.of(ContextHolder.currentContext).pop();
          yesFunction();
        },
        child: Text(yesText ?? 'yes'.tr()),
      ),
    ],
  );
}

void showTextInputDialog(String title, String hint, String? defaultValue,
    Function(String) onConfirm) {
  String value = defaultValue ?? '';
  showDialogBox(AlertDialog(
    title: Text(title),
    content: Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          hintText: hint,
          labelText: hint,
        ),
        autofocus: true,
        initialValue: defaultValue,
        onChanged: (String newValue) {
          value = newValue;
        },
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () {
          Navigator.of(ContextHolder.currentContext).pop();
        },
        child: Text('cancel'.tr()),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.of(ContextHolder.currentContext).pop();
          onConfirm(value);
        },
        child: Text('confirm'.tr()),
      ),
    ],
  ));
}

void showSnackBar(String message, {int duration = 1}) {
  ScaffoldMessenger.of(ContextHolder.currentContext).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
      backgroundColor: Colors.green.shade800,
    ),
  );
}

void showFullScreenDialog(Widget widget, {String? title}) {
  DataService().isOpen.value = false;
  showGeneralDialog(
    context: ContextHolder.currentContext,
    barrierDismissible: false,
    barrierLabel: 'Dialog',
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, __, ___) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(title ?? 'add_species'.tr()),
          leading: IconButton(
            onPressed: () => Navigator.of(ContextHolder.currentContext).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: widget,
      );
    },
  );
}

Future<void> showImportKMLDialog() async {
  final PlatformFile? picked = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['kml'],
  );
  if (picked == null) return;

  /// on mobile the picker always hands back a local copy; a null path would
  /// mean the file lives somewhere we cannot read as a File
  final String? path = picked.path;
  if (path == null) {
    showSnackBar('invalid_file_format'.tr());
    return;
  }

  final File file = File(path);
  final String fileData = await file.readAsString();
  final Transect transect =
      KMLUtils().kmlToTransect(fileData, file.lastModifiedSync());
  SembastService().addTransect(transect);
  DataService().setTransect(transect);
  showSnackBar('import_success'.tr());
}

Future<bool> showPermissionInfoDialog() async {
  bool result = false;
  await showDialog(
    context: ContextHolder.currentContext,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('location_permission_title'.tr()),
        content: Text(Platform.isIOS
            ? 'location_permission_content_ios'.tr()
            : 'location_permission_content'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              result = false;
            },
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              result = true;
            },
            child: Text('continue'.tr()),
          ),
        ],
      );
    },
  );
  return result;
}

Future<void> backupData([Rect? sharePositionOrigin]) async {
  try {
    String backupPath = await SembastService().createBackupPath();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupPath)],
        text: 'backup_text'.tr(),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } catch (e) {
    showSnackBar('backup_error'.tr(args: [e.toString()]));
  }
}

Future<void> restoreData() async {
  final PlatformFile? picked = await FilePicker.pickFile(
    type: FileType.any,
  );
  if (picked == null) return;

  final String? path = picked.path;
  if (path == null || picked.extension?.toLowerCase() != 'json') {
    showSnackBar('invalid_file_format'.tr());
    return;
  }

  try {
    showSnackBar('restoring_backup'.tr(), duration: 2);

    // JSON restore via SembastService
    await SembastService().restoreFromJson(path);
    showSnackBar('restore_success'.tr());
    DataService().setTransect(null);
  } catch (e) {
    showSnackBar('restore_error'.tr(args: [e.toString()]));
  }
}
