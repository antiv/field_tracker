import 'package:bird_tracker/service/data_service.dart';
import 'package:bird_tracker/service/sembast_service.dart';
import 'package:bird_tracker/widgets/species_form.dart';
import 'package:context_holder/context_holder.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../model/placemark.dart';
import '../utils/ux_builder.dart';

class MarkerInfo extends StatefulWidget {
  const MarkerInfo({
    super.key,
    required this.selected,
  });

  final Placemark? selected;

  @override
  State<MarkerInfo> createState() => _MarkerInfoState();
}

class _MarkerInfoState extends State<MarkerInfo> {
  void _addSpecies() {
    showFullScreenDialog(SpeciesForm(
      onSaved: (species, close) {
        setState(() {
          widget.selected?.endDate = DateTime.now();
          widget.selected?.species =
              widget.selected?.species?.toList(growable: true) ?? [];
          widget.selected?.species?.add(
            species,
          );
        });
        SembastService().updateTransect(DataService().transect!);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final speciesLength = widget.selected?.species?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '${'point'.tr()} ${(widget.selected?.id ?? 0) + 1}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.selected?.durationWithDay ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              Text(
                '${widget.selected?.species?.length} ${'species_title'.tr()}',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 16),
          Expanded(
            child: speciesLength > 0
                ? ListView.builder(
                    itemCount: speciesLength,
                    itemBuilder: (context, index) {
                      int revIdx = speciesLength - index - 1;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                                '${widget.selected?.species?[revIdx].species}'),
                            subtitle: Text(
                                '${'count_label'.tr()} ${widget.selected?.species?[revIdx].count} '
                                '${'time_label'.tr()} ${widget.selected?.species?[revIdx].time} '
                                '${'direction_label'.tr()} ${widget.selected?.species?[revIdx].direction?.toString().split('.').last ?? '-'} '
                                '${'strat_label'.tr()} ${widget.selected?.species?[revIdx].stratification?.toString().split('.').last ?? '-'}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDeleteWithPhotosDialog(
                                    widget.selected?.species?[revIdx].photos ??
                                        const [], (_) {
                                  setState(() {
                                    widget.selected?.species = widget
                                            .selected?.species
                                            ?.toList(growable: true) ??
                                        [];
                                    widget.selected?.species?.removeAt(revIdx);
                                  });

                                  /// the removal has to reach the database —
                                  /// setState alone brought the record back on
                                  /// the next load
                                  DataService()
                                      .transect
                                      ?.updateMarker(widget.selected!);
                                  SembastService()
                                      .updateTransect(DataService().transect!);
                                });
                              },
                            ),
                            onTap: () {
                              showFullScreenDialog(
                                SpeciesForm(
                                  species: widget.selected?.species?[revIdx],
                                  onSaved: (species, _) {
                                    setState(() {
                                      widget.selected?.species?[revIdx] =
                                          species;
                                    });
                                    DataService()
                                        .transect
                                        ?.updateMarker(widget.selected!);
                                    SembastService().updateTransect(
                                        DataService().transect!);
                                  },
                                ),
                                title: 'edit_species_title'.tr(),
                              );
                            }),
                      );
                    },
                  )
                : Text(widget.selected?.description ?? ''),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(ContextHolder.currentContext).pop(),
                child: Text('close'.tr()),
              ),
              const SizedBox(width: 12),
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
