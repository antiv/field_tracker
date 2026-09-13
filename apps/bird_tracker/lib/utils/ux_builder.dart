import 'dart:developer';
import 'dart:io';

import 'package:bird_tracker/service/data_service.dart';
import 'package:bird_tracker/service/media_service.dart';
import 'package:bird_tracker/service/sembast_service.dart';
import 'package:bird_tracker/utils/kml_utils.dart';
import 'package:bird_tracker/utils/kmz_utils.dart';
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

/// Confirm a delete that would leave photo files behind, with an opt-in to
/// delete them too. The checkbox starts **off**: a record vanishing from the
/// database must never take the pictures with it unless the user says so.
/// With no photos in play this is the plain yes/no dialog.
void showDeleteWithPhotosDialog(
    List<String> photos, void Function(bool deletePhotos) onConfirm) {
  if (photos.isEmpty) {
    showYesNoDialog(() => onConfirm(false), () {});
    return;
  }

  bool deletePhotos = false;
  showDialogBox(StatefulBuilder(
    builder: (context, setState) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('are_you_sure'.tr(), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: deletePhotos,
            onChanged: (value) => setState(() => deletePhotos = value ?? false),
            title: Text('delete_photos_too'.tr(args: ['${photos.length}'])),
            subtitle: Text('delete_photos_hint'.tr(),
                style: const TextStyle(fontSize: 12)),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ContextHolder.currentContext).pop(),
          child: Text('no'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ContextHolder.currentContext).pop();
            if (deletePhotos) MediaService().delete(photos);
            onConfirm(deletePhotos);
          },
          child: Text('yes'.tr()),
        ),
      ],
    ),
  ));
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

/// Imports either format the app exports. A KMZ brings its photos with it;
/// a plain KML brings only the names they had.
Future<void> showImportDialog() async {
  /// deliberately not FileType.custom: that maps the extensions through
  /// Android's MimeTypeMap, which knows neither kml nor kmz, and the files
  /// end up greyed out in the picker. Filter here instead, the way
  /// [restoreData] does.
  final PlatformFile? picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null) return;

  /// on mobile the picker always hands back a local copy; a null path would
  /// mean a cloud entry we cannot read
  final String? path = picked.path;
  if (path == null) {
    showSnackBar('invalid_file_format'.tr());
    return;
  }

  final File file = File(path);
  final DateTime fileDate = file.lastModifiedSync();
  try {
    /// The format is decided by what the file *is*, not what it is called.
    /// Mail clients, chat apps and cloud drives rename attachments freely —
    /// one came back as "Transect 30.08.2026 as KMZ" with no extension at
    /// all, and reading a zip as UTF-8 fails with a decode error rather than
    /// anything a user could act on.
    final Transect transect = await _isZip(file)
        ? await KMZUtils.readKMZ(path, fileDate)
        : KMLUtils().kmlToTransect(await file.readAsString(), fileDate);
    await SembastService().addTransect(transect);
    DataService().setTransect(transect);
    showSnackBar('import_success'.tr());
  } catch (e) {
    log('Could not import ${picked.name}: ${e.toString()}');
    showSnackBar('invalid_file_format'.tr());
  }
}

/// Every zip — and so every KMZ — starts with the local file header magic.
Future<bool> _isZip(File file) async {
  final RandomAccessFile handle = await file.open();
  try {
    final head = await handle.read(4);
    return head.length == 4 &&
        head[0] == 0x50 &&
        head[1] == 0x4B &&
        head[2] == 0x03 &&
        head[3] == 0x04;
  } catch (e) {
    return false;
  } finally {
    await handle.close();
  }
}

Future<bool> showPermissionInfoDialog() => _showRationaleDialog(
      'location_permission_title'.tr(),
      Platform.isIOS
          ? 'location_permission_content_ios'.tr()
          : 'location_permission_content'.tr(),
    );

/// Second step of the Android permission flow: "Allow all the time" has to be
/// requested on its own, after the foreground grant, or Android 11+ shows
/// nothing at all. Google also expects a rationale immediately before it.
Future<bool> showBackgroundPermissionInfoDialog() => _showRationaleDialog(
      'location_background_title'.tr(),
      'location_background_content'.tr(),
    );

/// Shown when the background request came back denied: on Android 11+ the only
/// place left to grant it is the app's own settings page.
Future<bool> showBackgroundPermissionDeniedDialog() => _showRationaleDialog(
      'location_background_title'.tr(),
      'location_background_denied'.tr(),
      confirmText: 'open_settings'.tr(),
    );

/// Foreground location was refused for good ("Don't ask again", or revoked in
/// settings): the system will not show a prompt any more, so the only way
/// forward is the app's own settings page.
Future<bool> showLocationDeniedForeverDialog() => _showRationaleDialog(
      'location_permission_title'.tr(),
      'location_permission_denied_forever'.tr(),
      confirmText: 'open_settings'.tr(),
    );

/// Android 12+ "Approximate location": the grant is real but useless for a
/// survey route, and a re-request is what shows the upgrade-to-precise prompt.
Future<bool> showPreciseLocationDialog() => _showRationaleDialog(
      'location_permission_title'.tr(),
      'precise_location_required'.tr(),
      confirmText: 'open_settings'.tr(),
    );

Future<bool> _showRationaleDialog(String title, String content,
    {String? confirmText}) async {
  bool result = false;
  await showDialog(
    context: ContextHolder.currentContext,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
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
            child: Text(confirmText ?? 'continue'.tr()),
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
  final PlatformFile? picked = await FilePicker.pickFile(type: FileType.any);
  if (picked == null) return;

  final String? path = picked.path;
  const accepted = {'json', 'zip'};
  if (path == null || !accepted.contains(picked.extension?.toLowerCase())) {
    showSnackBar('invalid_file_format'.tr());
    return;
  }

  try {
    showSnackBar('restoring_backup'.tr(), duration: 2);

    /// .zip carries the photos too; plain .json is the older backup format
    await SembastService().restoreFromBackup(path);
    showSnackBar('restore_success'.tr());
    DataService().setTransect(null);
  } catch (e) {
    showSnackBar('restore_error'.tr(args: [e.toString()]));
  }
}
