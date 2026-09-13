import 'package:bird_tracker/widgets/transect_info.dart';
import 'package:bird_tracker/widgets/transects_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:easy_localization/easy_localization.dart';
import '../configuration/constants.dart';
import '../service/data_service.dart';
import '../utils/ux_builder.dart';

class AppMenu extends StatelessWidget {
  const AppMenu({super.key});

  void _showTracksHistory() => showBottomModal(const TransectsHistory());

  void _showTrackInfo() {
    if (DataService().transect != null) {
      showBottomModal(const TransectInfo());
    } else {
      showSnackBar('no_transect_selected'.tr());
    }
  }

  void _openPrivacyPolicy() async {
    final url = dotenv.env['PRIVACY_POLICY_URL'];
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showAboutDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ant-biocode.png',
              height: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'app_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'app_version'.tr(args: [packageInfo.version]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'about_description'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 32),
            Text(
              'copyright'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).canvasColor,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSectionHeader(context, 'field_work'.tr()),
                ListTile(
                  leading:
                      const Icon(Icons.fmd_bad_outlined, color: Colors.green),
                  title: Text('current_track'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    _showTrackInfo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.green),
                  title: Text('saved_tracks'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    _showTracksHistory();
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSectionHeader(context, 'data_management'.tr()),
                ListTile(
                  leading:
                      const Icon(Icons.file_open_outlined, color: Colors.green),
                  title: Text('import_map'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    showImportDialog();
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.backup_outlined, color: Colors.green),
                  title: Text('backup_data'.tr()),
                  onTap: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final rect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
                    Navigator.pop(context);
                    backupData(rect);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined,
                      color: Colors.green),
                  title: Text('restore_data'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    restoreData();
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSectionHeader(context, 'configuration'.tr()),
                ExpansionTile(
                  leading: const Icon(Icons.tune, color: Colors.green),
                  title: Text('settings'.tr()),
                  children: <Widget>[
                    ListTile(
                      title: Text('select_map_type'.tr()),
                      leading: const Icon(Icons.layers_outlined),
                      subtitle: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _mapTypeButton(context, MapType.normal, 'map'.tr()),
                            _mapTypeButton(
                                context, MapType.satellite, 'satellite'.tr()),
                            _mapTypeButton(
                                context, MapType.hybrid, 'hybrid'.tr()),
                          ],
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text('set_email'.tr()),
                      leading: const Icon(Icons.email_outlined),
                      onTap: () {
                        Navigator.pop(context);
                        showTextInputDialog(
                          'email_dialog_title'.tr(),
                          'email_dialog_hint'.tr(),
                          DataService().getEmailPreference(),
                          (value) {
                            DataService().setEmailPreference(value);
                          },
                        );
                      },
                    ),
                    ListTile(
                      title: Text('set_point_radius'.tr()),
                      leading: const Icon(Icons.radar_outlined),
                      onTap: () {
                        Navigator.pop(context);
                        showTextInputDialog(
                          'point_radius_dialog_title'.tr(),
                          'point_radius_dialog_hint'.tr(),
                          DataService().getPointRadiusPreference().toString(),
                          (value) {
                            final radius = int.tryParse(value);
                            if (radius != null) {
                              DataService().setPointRadiusPreference(radius);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: Colors.green),
                  title: Text('privacy_policy'.tr()),
                  onTap: () {
                    Navigator.pop(context);
                    _openPrivacyPolicy();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade700,
            Colors.green.shade400,
          ],
        ),
      ),
      padding: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SvgPicture.asset(
              kAppIcon,
              width: 48,
              height: 48,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'app_title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    return Text(
                      'app_version'.tr(args: [
                        snapshot.hasData ? snapshot.data!.version : ''
                      ]),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showAboutDialog(context),
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'About',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _mapTypeButton(BuildContext context, MapType type, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: OutlinedButton(
        onPressed: () {
          DataService().setMapType(type);
          Navigator.pop(context);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: Colors.green),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class MenuIcon extends StatelessWidget {
  const MenuIcon({
    super.key,
    this.asset,
    this.height,
  });

  final String? asset;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/${asset ?? 'eagle'}.svg',
      height: height ?? 24,
      semanticsLabel: 'Bird Tracker Logo',
      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
    );
  }
}
