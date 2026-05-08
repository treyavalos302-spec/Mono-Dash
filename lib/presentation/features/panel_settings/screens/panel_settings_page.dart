import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../common/components/sub_menu_page.dart';
import '../../server_detail/providers/active_server_provider.dart';
import 'panel_page.dart';
import 'security_page.dart';
import 'alert_page.dart';
import 'backup_account_page.dart';
import 'snapshot_page.dart';
import 'about_page.dart';

class PanelSettingsPage extends StatelessWidget {
  const PanelSettingsPage({super.key, required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: _PanelSettingsContent(serverId: serverId),
    );
  }
}

class _PanelSettingsContent extends StatelessWidget {
  const _PanelSettingsContent({required this.serverId});

  final int serverId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SubMenuPage(
      title: l10n.panelSettings_title,
      sections: [
        SubMenuSection(
          items: [
            SubMenuItem(
              title: l10n.panelSettings_panel,
              icon: TablerIcons.layout_dashboard,
              iconColor: CupertinoColors.activeBlue,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => PanelPage(serverId: serverId),
                ),
              ),
            ),
            SubMenuItem(
              title: l10n.panelSettings_security,
              icon: TablerIcons.shield_lock,
              iconColor: CupertinoColors.systemGreen,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SecurityPage(serverId: serverId),
                ),
              ),
            ),
          ],
        ),
        SubMenuSection(
          items: [
            SubMenuItem(
              title: l10n.panelSettings_alerts,
              icon: TablerIcons.bell,
              iconColor: CupertinoColors.systemOrange,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => AlertPage(serverId: serverId),
                ),
              ),
            ),
            SubMenuItem(
              title: l10n.panelSettings_backupAccounts,
              icon: TablerIcons.cloud_upload,
              iconColor: CupertinoColors.systemTeal,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => BackupAccountPage(serverId: serverId),
                ),
              ),
            ),
            SubMenuItem(
              title: l10n.panelSettings_snapshots,
              icon: TablerIcons.camera,
              iconColor: CupertinoColors.systemIndigo,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SnapshotPage(serverId: serverId),
                ),
              ),
            ),
          ],
        ),
        // SubMenuSection(
        //   items: [
        //     SubMenuItem(
        //       title: l10n.panelSettings_about,
        //       icon: TablerIcons.info_circle,
        //       iconColor: CupertinoColors.systemGrey,
        //       onTap: () => Navigator.of(context).push(
        //         CupertinoPageRoute<void>(builder: (_) => const AboutPage()),
        //       ),
        //     ),
        //   ],
        // ),
      ],
    );
  }
}
