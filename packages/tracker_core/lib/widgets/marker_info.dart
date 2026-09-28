import 'package:context_holder/context_holder.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../config/tracker_config.dart';
import '../model/placemark.dart';
import '../service/data_service.dart';
import '../service/media_service.dart';
import '../service/sembast_service.dart';
import '../utils/ux_builder.dart';
import 'photo_strip.dart';
import 'record_form_shell.dart';

class MarkerInfo extends StatefulWidget {
  const MarkerInfo({super.key, required this.selected});

  final Placemark? selected;

  @override
  State<MarkerInfo> createState() => _MarkerInfoState();
}

class _MarkerInfoState extends State<MarkerInfo> {
  void _addSpecies() {
    showFullScreenDialog(
      RecordFormShell(
        onSaved: (record, close) {
          setState(() {
            widget.selected?.endDate = DateTime.now();
            widget.selected?.records =
                widget.selected?.records?.toList(growable: true) ?? [];
            widget.selected?.records?.add(record);
          });
          SembastService().updateTransect(DataService().transect!);
        },
      ),
    );
  }

  /// Point photos are saved the moment they change: there is no form to
  /// cancel here, so a photo the strip dropped (after its own confirmation)
  /// is gone for good and its file goes with it. The gallery copy stays.
  void _setPhotos(List<String> names) {
    final point = widget.selected;
    if (point == null) return;
    final removed = point.photos.toSet().difference(names.toSet());
    setState(() => point.photos = names);
    final active = DataService().transect;
    if (active != null) {
      active.updateMarker(point);
      SembastService().updateTransect(active);
    }
    if (removed.isNotEmpty) MediaService().delete(removed);
  }

  /// newest record first
  Widget _recordCard(BuildContext context, int index) {
    final speciesLength = widget.selected?.records?.length ?? 0;
    int revIdx = speciesLength - index - 1;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(widget.selected!.records![revIdx].species),
        subtitle: Text(widget.selected!.records![revIdx].subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            showDeleteWithPhotosDialog(
              widget.selected?.records?[revIdx].photos ?? const [],
              (_) {
                setState(() {
                  widget.selected?.records =
                      widget.selected?.records?.toList(growable: true) ?? [];
                  widget.selected?.records?.removeAt(revIdx);
                });

                /// the removal has to reach the database —
                /// setState alone brought the record back on
                /// the next load
                DataService().transect?.updateMarker(widget.selected!);
                SembastService().updateTransect(DataService().transect!);
              },
              title: 'delete_record_confirm'.tr(),
            );
          },
        ),
        onTap: () {
          showFullScreenDialog(
            RecordFormShell(
              existing: widget.selected?.records?[revIdx],
              onSaved: (record, _) {
                setState(() {
                  widget.selected?.records?[revIdx] = record;
                });
                DataService().transect?.updateMarker(widget.selected!);
                SembastService().updateTransect(DataService().transect!);
              },
            ),
            title: 'edit_species_title'.tr(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speciesLength = widget.selected?.records?.length ?? 0;

    /// one record per point: once it is there, the point is edited by
    /// tapping it, not extended
    final canAdd =
        !TrackerConfig.current.singleRecordPerPoint || speciesLength == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// header, photos and records scroll as one: the photo strip gets
          /// out of the way once the list is scrolled, and a drag anywhere
          /// above the buttons grows the sheet (see showBottomModal)
          Expanded(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '${'point'.tr()} ${(widget.selected?.id ?? 0) + 1}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.selected?.durationWithDay ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          Text(
                            '$speciesLength ${'species_title'.tr()}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PhotoStrip(
                        names: widget.selected?.photos ?? const [],
                        onChanged: _setPhotos,
                        label: 'point_photos'.tr(),
                      ),
                      const Divider(height: 16),
                    ],
                  ),
                ),
                if (speciesLength > 0)
                  SliverList.builder(
                    itemCount: speciesLength,
                    itemBuilder: _recordCard,
                  )
                else
                  SliverToBoxAdapter(
                    child: Text(widget.selected?.description ?? ''),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(ContextHolder.currentContext).pop(),
                child: Text('close'.tr()),
              ),
              if (canAdd) const SizedBox(width: 12),
              if (canAdd)
                ElevatedButton.icon(
                  onPressed: () => _addSpecies(),
                  icon: const Icon(Icons.add),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  label: Text('add_species_btn'.tr()),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
