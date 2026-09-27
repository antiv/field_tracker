import 'package:tracker_core/service/sembast_service.dart';
import 'package:tracker_core/utils/location_helper.dart';
import 'package:context_holder/context_holder.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../model/transect.dart';
import '../service/data_service.dart';
import '../utils/ux_builder.dart';

class TransectsHistory extends StatefulWidget {
  const TransectsHistory({super.key});

  @override
  State<TransectsHistory> createState() => _TransectsHistoryState();
}

class _TransectsHistoryState extends State<TransectsHistory> {
  List<Transect> transects = [];

  /// Selection mode: entered by a long press or the Select button, left by
  /// the close button or once the selected transects are deleted. Keyed by
  /// id, so a reload of the list keeps what was ticked.
  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    _getTransects();
    super.initState();
  }

  Future<void> _getTransects() async {
    final List<Transect> transects = await SembastService().getAllTransects();
    setState(() {
      this.transects = transects;
    });
  }

  List<Transect> get _selectedTransects =>
      transects.where((t) => _selected.contains(t.id)).toList();

  void _toggle(Transect transect) {
    setState(() {
      if (!_selected.remove(transect.id)) _selected.add(transect.id);
    });
  }

  void _startSelecting([Transect? first]) {
    setState(() {
      _selecting = true;
      if (first != null) _selected.add(first.id);
    });
  }

  void _stopSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == transects.length) {
        _selected.clear();
      } else {
        _selected.addAll(transects.map((t) => t.id));
      }
    });
  }

  /// Single and bulk delete alike. A deleted transect that is the one on the
  /// map goes off the map too — the recording, if it was the active one,
  /// stops with it (home_page reacts to the cleared transect).
  void _delete(List<Transect> doomed, {String? title}) {
    if (doomed.isEmpty) return;
    showDeleteWithPhotosDialog(
      [for (final t in doomed) ...t.photoNames],
      (_) async {
        for (final t in doomed) {
          await SembastService().deleteTransect(t);
        }
        final ids = doomed.map((t) => t.id).toSet();
        if (ids.contains(DataService().transect?.id)) {
          DataService().clearTransect();
        }
        if (!mounted) return;
        setState(() {
          transects.removeWhere((t) => ids.contains(t.id));
          _selected.removeAll(ids);
          if (_selecting && _selected.isEmpty) _selecting = false;
        });
      },
      title: title ?? 'delete_transects_confirm'.tr(args: ['${doomed.length}']),
    );
  }

  /// The share sheet on iPad anchors to the button that opened it.
  static Rect? _originOf(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    return box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
  }

  static final ButtonStyle _smallButton = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _shareButton(String label, void Function(Rect?) share) => Builder(
    builder: (buttonContext) => ElevatedButton.icon(
      onPressed: () => share(_originOf(buttonContext)),
      icon: const Icon(Icons.share, size: 14),
      style: _smallButton,
      label: Text(label, style: const TextStyle(fontSize: 11)),
    ),
  );

  Widget _header(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    if (_selecting) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: _stopSelecting,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                'selected_count'.tr(args: ['${_selected.length}']),
                style: titleStyle,
              ),
            ),
            TextButton.icon(
              onPressed: _toggleAll,
              icon: Icon(
                _selected.length == transects.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              label: Text('select_all'.tr()),
            ),
          ],
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Text('history_title'.tr(), style: titleStyle),
        if (transects.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _startSelecting,
                icon: const Icon(Icons.checklist),
                label: Text('select_transects'.tr()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer() {
    if (!_selecting) {
      return OutlinedButton(
        onPressed: () => Navigator.pop(ContextHolder.currentContext),
        child: Text('close'.tr()),
      );
    }
    final picked = _selectedTransects;
    final enabled = picked.isNotEmpty;
    final kmz = picked.any((t) => t.hasPhotos);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (buttonContext) => ElevatedButton.icon(
                onPressed: enabled
                    ? () =>
                          Transect.shareCSVOf(picked, _originOf(buttonContext))
                    : null,
                icon: const Icon(Icons.share, size: 18),
                label: FittedBox(child: Text('csv'.tr())),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (buttonContext) => ElevatedButton.icon(
                onPressed: enabled
                    ? () =>
                          Transect.shareKMLOf(picked, _originOf(buttonContext))
                    : null,
                icon: const Icon(Icons.share, size: 18),
                label: FittedBox(child: Text(kmz ? 'kmz'.tr() : 'kml'.tr())),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: enabled ? () => _delete(picked) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete, size: 18),
              label: FittedBox(child: Text('delete_selected'.tr())),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        _header(context),
        const SizedBox(height: 4),
        Expanded(
          child: transects.isNotEmpty
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: transects.length,
                  itemBuilder: (BuildContext context, int index) {
                    final transect = transects[index];
                    final selected = _selected.contains(transect.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 8,
                      ),
                      color: selected ? Colors.green.shade50 : null,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        selected: selected,
                        onTap: () {
                          if (_selecting) {
                            _toggle(transect);
                            return;
                          }
                          DataService().setTransect(transect);
                          Navigator.pop(ContextHolder.currentContext);
                        },
                        onLongPress: _selecting
                            ? null
                            : () => _startSelecting(transect),
                        leading: _selecting
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(transect),
                              )
                            : null,
                        title: Text(
                          transect.name ??
                              '${'transect'.tr()} ${transect.id}: '
                                  '${DateFormat('dd.MM.yyyy HH:mm').format(transect.startDate)} - '
                                  '${transect.endDate != null ? DateFormat('HH:mm').format(transect.endDate!) : 'in_progress'.tr()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'markers'.tr()}: ${transect.markers?.length ?? 0} '
                              '${'distance'.tr()}: ${calculateDistance(transect.points?.map((e) => LatLng(e.latitude, e.longitude)).toList() ?? []).toStringAsFixed(2)}km '
                              '${'time'.tr()}: ${getTimeDifference(transect.startDate, transect.endDate ?? DateTime.now())}',
                              style: const TextStyle(fontSize: 11),
                            ),

                            /// in selection mode the actions live in the
                            /// footer and apply to every ticked transect
                            if (!_selecting)
                              Row(
                                children: [
                                  _shareButton('csv'.tr(), transect.shareCSV),
                                  const SizedBox(width: 8),
                                  _shareButton(
                                    transect.hasPhotos
                                        ? 'kmz'.tr()
                                        : 'kml'.tr(),
                                    transect.shareKML,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        isThreeLine: !_selecting,
                        trailing: _selecting
                            ? null
                            : IconButton(
                                onPressed: () => _delete([
                                  transect,
                                ], title: 'delete_transect_confirm'.tr()),
                                icon: const Icon(Icons.delete),
                              ),
                      ),
                    );
                  },
                )
              : Center(child: Text('no_transects_yet'.tr())),
        ),
        const SizedBox(height: 8),
        _footer(),
        const SizedBox(height: 8),
      ],
    );
  }
}
