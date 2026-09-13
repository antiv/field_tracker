import 'package:bird_tracker/service/sembast_service.dart';
import 'package:context_holder/context_holder.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../service/data_service.dart';
import '../utils/location_helper.dart';
import '../utils/ux_builder.dart';

class TransectInfo extends StatefulWidget {
  const TransectInfo({super.key});

  @override
  State<TransectInfo> createState() => _TransectInfoState();
}

class _TransectInfoState extends State<TransectInfo> {
  @override
  Widget build(BuildContext context) {
    final current = DataService().transect;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'transect_info'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                current?.dateRange ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              Text(
                '${current?.markers?.length} ${'points'.tr()}',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${'duration'.tr()}: ${current?.duration ?? ''}', style: const TextStyle(fontSize: 13)),
          Text('${'distance'.tr()}: ${current?.distanceString ?? ''}', style: const TextStyle(fontSize: 13)),
          const Divider(height: 16),
          Expanded(
            // height: 340,
            child: ListView.builder(
              itemCount: current?.markers?.length ?? 0,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                          '${'marker'.tr()} ${(current?.markers?[index].id ?? 0) + 1}'),
                      subtitle: Text(
                          '${'species_title'.tr()}: ${current?.markers?[index].species?.length} '
                          '${'time'.tr()}: ${current?.markers?[index].duration} '),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          /// Ask for confirmation — and, when the point holds
                          /// photos, whether those files should go too
                          showDeleteWithPhotosDialog(
                              current?.markers?[index].photoNames ?? const [],
                              (_) => setState(() {
                                    current?.markers = current.markers
                                            ?.toList(growable: true) ??
                                        [];
                                    current?.markers?.removeAt(index);
                                    SembastService().updateTransect(current!);
                                    DataService().notify();
                                  }));
                        },
                      ),
                      onTap: () {
                        // Navigator.pop(context);
                        showMarkerInfo(current?.markers?[index].id ?? 0);
                      }),
                );
              },
            ),
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
                onPressed: () {
                  Navigator.of(ContextHolder.currentContext).pop();
                  if (current != null && current.endDate == null) {
                    /// clearing the map while a transect is active ends it —
                    /// it must not stay open in the database
                    showYesNoDialog(() {
                      current.endDate = DateTime.now();
                      SembastService().updateTransect(current);
                      DataService().clearTransect();
                    }, () {}, title: 'clear_map_ends_transect'.tr());
                  } else {
                    DataService().clearTransect();
                  }
                },
                icon: const Icon(Icons.clear_all),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade900,
                ),
                label: Text('clear_map'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
