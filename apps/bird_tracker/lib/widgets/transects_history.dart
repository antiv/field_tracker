import 'package:bird_tracker/service/sembast_service.dart';
import 'package:bird_tracker/utils/location_helper.dart';
import 'package:context_holder/context_holder.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../model/transect.dart';
import '../service/data_service.dart';
import '../utils/ux_builder.dart';

class TransectsHistory extends StatefulWidget {
  const TransectsHistory({
    super.key,
  });

  @override
  State<TransectsHistory> createState() => _TransectsHistoryState();
}

class _TransectsHistoryState extends State<TransectsHistory> {
  List<Transect> transects = [];

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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'history_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: transects.isNotEmpty
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: transects.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          onTap: () {
                            DataService().setTransect(transects[index]);
                            Navigator.pop(ContextHolder.currentContext);
                          },
                          // leading: const Icon(Icons.map_outlined),
                          title: Text(
                            transects[index].name ??
                                'Transect ${transects[index].id}: '
                                    '${DateFormat('dd.MM.yyyy HH:mm').format(transects[index].startDate)} - '
                                    '${transects[index].endDate != null ? DateFormat('HH:mm').format(transects[index].endDate!) : 'in_progress'.tr()}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          // onTap: () {
                          //   Navigator.of(context).pop();
                          // },
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${'markers'.tr()}: ${transects[index].markers?.length ?? 0} '
                                '${'distance'.tr()}: ${calculateDistance(transects[index].points?.map((e) => LatLng(e.latitude, e.longitude)).toList() ?? []).toStringAsFixed(2)}km '
                                '${'time'.tr()}: ${getTimeDifference(transects[index].startDate, transects[index].endDate ?? DateTime.now())}',
                                style: const TextStyle(fontSize: 11),
                              ),
                                Row(children: [
                                  Builder(
                                    builder: (buttonContext) => ElevatedButton.icon(
                                      onPressed: () {
                                        final box = buttonContext.findRenderObject() as RenderBox?;
                                        final rect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
                                        transects[index].shareCSV(rect);
                                      },
                                      icon: const Icon(Icons.share, size: 14),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      label: Text('csv'.tr(), style: const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Builder(
                                    builder: (buttonContext) => ElevatedButton.icon(
                                      onPressed: () {
                                        final box = buttonContext.findRenderObject() as RenderBox?;
                                        final rect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
                                        transects[index].shareKML(rect);
                                      },
                                      icon: const Icon(Icons.share, size: 14),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      label: Text(
                                          transects[index].hasPhotos ? 'kmz'.tr() : 'kml'.tr(),
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                ]),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            onPressed: () {
                              showDeleteWithPhotosDialog(
                                  transects[index].photoNames, (_) {
                                SembastService().deleteTransect(transects[index]);
                                setState(() {
                                  transects.removeAt(index);
                                });
                              });
                            },
                            icon: const Icon(Icons.delete),
                          )),
                    );
                  },
                )
              : Center(child: Text('no_transects_yet'.tr())),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(ContextHolder.currentContext),
          child: Text('close'.tr()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
