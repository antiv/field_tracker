import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;

import 'package:easy_localization/easy_localization.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/ux_builder.dart';

/// Album the photos show up under in the device gallery.
const String kGalleryAlbum = 'Bird Tracker';

/// Directory inside the app documents folder holding the canonical copies.
const String kMediaDirName = 'media';

/// Photos attached to a record live in two places: the canonical copy under
/// `<appDocuments>/media`, which every export and every thumbnail reads, and a
/// user-visible copy in the "Bird Tracker" gallery album. Records persist the
/// **file name only** — on iOS the app container path changes between installs,
/// so an absolute path would break as soon as the app is updated.
class MediaService {
  static final MediaService _singleton = MediaService._internal();

  factory MediaService() => _singleton;

  MediaService._internal();

  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

  String? _dirPath;

  /// [root] exists so tests can point the store at a temp directory; the app
  /// always uses the documents directory.
  Future<void> init({String? root}) async {
    if (_dirPath != null && root == null) return;
    final base = root ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(p.join(base, kMediaDirName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _dirPath = dir.path;
  }

  /// Synchronous on purpose — `Image.file` is built inside `build()`, which
  /// cannot await. [init] runs at startup, so the path is there by then.
  String get dirPath => _dirPath ?? '';

  File fileFor(String name) => File(p.join(dirPath, name));

  bool exists(String name) => dirPath.isNotEmpty && fileFor(name).existsSync();

  /// Take a photo. Returns the stored file name, or null if the user backed
  /// out of the camera.
  Future<String?> capture() async {
    try {
      final shot = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 2400, imageQuality: 88);
      if (shot == null) return null;
      return await _import(shot);
    } catch (e) {
      log('Camera capture failed: ${e.toString()}');
      showSnackBar('photo_camera_failed'.tr());
      return null;
    }
  }

  /// Pick one or more existing photos. They are copied in, so a later deletion
  /// of the original never empties a record.
  Future<List<String>> pickFromGallery() async {
    try {
      final picked =
          await _picker.pickMultiImage(maxWidth: 2400, imageQuality: 88);
      final names = <String>[];
      for (final image in picked) {
        final name = await _import(image);
        if (name != null) names.add(name);
      }
      return names;
    } catch (e) {
      log('Gallery pick failed: ${e.toString()}');
      showSnackBar('photo_gallery_pick_failed'.tr());
      return [];
    }
  }

  /// Synchronous inside on purpose: [SpeciesForm.dispose] fires this without
  /// awaiting, and a pending async delete would outlive the widget.
  Future<void> delete(Iterable<String> names) async {
    for (final name in names) {
      try {
        final file = fileFor(name);
        if (file.existsSync()) file.deleteSync();
      } catch (e) {
        log('Could not delete photo $name: ${e.toString()}');
      }
    }
  }

  /// Write [bytes] under [name], used when a KMZ or a backup archive is
  /// unpacked. Overwrites — the archive is the source of truth there.
  Future<void> writeBytes(String name, List<int> bytes) async {
    await init();
    await fileFor(p.basename(name)).writeAsBytes(bytes, flush: true);
  }

  /// File names currently on disk — the orphan sweep after a restore needs it.
  List<String> listNames() {
    if (dirPath.isEmpty) return [];
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList();
  }

  Future<void> deleteOrphans(Set<String> keep) async {
    final orphans = listNames().where((name) => !keep.contains(name));
    await delete(orphans.toList());
  }

  /// Sortable and collision-free: the timestamp orders the strip the way the
  /// records were taken, the suffix covers two shots in the same second.
  String _newName() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final suffix = _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return 'BT_${stamp}_$suffix.jpg';
  }

  Future<String?> _import(XFile source) async {
    await init();
    final name = _newName();
    final target = fileFor(name);
    await target.writeAsBytes(await source.readAsBytes(), flush: true);
    await _addToGallery(target.path);
    return name;
  }

  /// A failed gallery write must not lose the record — the canonical copy is
  /// already on disk, so the photo only misses its shortcut in Photos.
  Future<void> _addToGallery(String path) async {
    try {
      await Gal.putImage(path, album: kGalleryAlbum);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        try {
          await Gal.requestAccess(toAlbum: true);
          await Gal.putImage(path, album: kGalleryAlbum);
          return;
        } catch (retry) {
          log('Gallery access still denied: ${retry.toString()}');
        }
      } else {
        log('Could not save to gallery: ${e.type.message}');
      }
      showSnackBar('photo_gallery_failed'.tr(), duration: 2);
    } catch (e) {
      log('Could not save to gallery: ${e.toString()}');
      showSnackBar('photo_gallery_failed'.tr(), duration: 2);
    }
  }
}
