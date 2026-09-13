import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../service/media_service.dart';
import '../utils/ux_builder.dart';

/// Horizontal strip of record photos with a camera and a gallery button.
///
/// Fixed height and horizontal scrolling on purpose: [SpeciesForm] is a
/// column that already overflows in Serbian on a small phone, so this must
/// never grow with the number of photos.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({super.key, required this.names, required this.onChanged});

  final List<String> names;
  final ValueChanged<List<String>> onChanged;

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  static const double _tile = 72;

  bool _busy = false;

  Future<void> _run(Future<List<String>> Function() pick) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final added = await pick();
      if (added.isEmpty) return;
      if (!mounted) {
        /// the form was closed while the camera was open — nothing will ever
        /// reference these files, and no one else is left to clean them up
        await MediaService().delete(added);
        return;
      }
      widget.onChanged([...widget.names, ...added]);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Only drops the name — the file is the form's to delete, and only once a
  /// save makes the removal permanent. Cancelling must leave the record whole.
  void _remove(String name) {
    showYesNoDialog(() {
      widget.onChanged(widget.names.where((n) => n != name).toList());
    }, () {}, title: 'delete_photo'.tr());
  }

  void _preview(String name) {
    showFullScreenDialog(
      InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(MediaService().fileFor(name))),
      ),
      title: 'photos'.tr(),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: _tile,
        height: _tile,
        child: OutlinedButton(
          onPressed: _busy ? null : onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(String name) {
    final file = MediaService().fileFor(name);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: _tile,
        height: _tile,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _preview(name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover, cacheWidth: 216)
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: IconButton(
                icon: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 13, color: Colors.white),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: () => _remove(name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('photos'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (_busy) ...[
              const SizedBox(width: 8),
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _tile,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _action(Icons.photo_camera_outlined, 'add_photo_camera'.tr(),
                  () => _run(() async {
                        final name = await MediaService().capture();
                        return name == null ? <String>[] : [name];
                      })),
              _action(Icons.photo_library_outlined, 'add_photo_gallery'.tr(),
                  () => _run(() => MediaService().pickFromGallery())),
              ...widget.names.map(_thumbnail),
            ],
          ),
        ),
      ],
    );
  }
}
