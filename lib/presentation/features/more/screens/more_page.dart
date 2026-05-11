import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/sub_menu_page.dart';
import '../../../common/components/terminal/app_terminal.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../../app_store/screens/app_store_page.dart';
import '../../databases/screens/database_page.dart';
import '../../websites/screens/ssl_manage_page.dart';
import '../../cronjobs/screens/cronjob_page.dart';
import '../../log/screens/log_hub_page.dart';
import '../../panel_settings/screens/panel_settings_page.dart';
import '../../runtimes/screens/runtime_page.dart';
import '../../firewall/screens/firewall_page.dart';
import '../../process/screens/process_page.dart';
import '../../ssh/screens/ssh_page.dart';
import '../../supervisor/screens/supervisor_page.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key, required this.onOpenFilesPath});

  final ValueChanged<String> onOpenFilesPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final serverId = ref.watch(activeServerIdProvider);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: FrostedScaffold.contentTopPadding(context) + 8,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
          sliver: SliverList.list(
            children: [
              SubMenuCard(
                title: l10n.more_appsServices,
                children: [
                  SubMenuRow(
                    icon: TablerIcons.apps,
                    iconColor: CupertinoColors.activeBlue,
                    title: l10n.more_appStoreTitle,
                    subtitle: l10n.more_appStoreSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => AppStorePage(serverId: serverId),
                      ),
                    ),
                  ),
                  // SubMenuRow(
                  //   icon: TablerIcons.tool,
                  //   iconColor: CupertinoColors.systemTeal,
                  //   title: '工具箱',
                  //   subtitle: '快速设置、缓存清理、进程守护等',
                  //   onTap: () => Navigator.of(context).push(
                  //     CupertinoPageRoute<void>(
                  //       builder: (_) => ToolboxPage(serverId: serverId),
                  //     ),
                  //   ),
                  // ),
                  SubMenuRow(
                    icon: TablerIcons.terminal_2,
                    iconColor: CupertinoColors.systemGrey,
                    title: l10n.more_terminalTitle,
                    subtitle: l10n.more_terminalSubtitle,
                    onTap: () => showAppTerminal(
                      context,
                      containerId: '',
                      command: '/bin/bash',
                      source: 'host',
                    ),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.shield_cog,
                    iconColor: CupertinoColors.systemTeal,
                    title: l10n.supervisor_menuTitle,
                    subtitle: l10n.supervisor_menuSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => SupervisorPage(
                          serverId: serverId,
                          onOpenFilesPath: onOpenFilesPath,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SubMenuCard(
                title: l10n.more_webServices,
                children: [
                  SubMenuRow(
                    icon: TablerIcons.certificate,
                    iconColor: CupertinoColors.systemGreen,
                    title: l10n.more_sslTitle,
                    subtitle: l10n.more_sslSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => SslManagePage(serverId: serverId),
                      ),
                    ),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.server_2,
                    iconColor: CupertinoColors.systemIndigo,
                    title: l10n.more_runtimeTitle,
                    subtitle: l10n.more_runtimeSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => RuntimePage(
                          serverId: serverId,
                          onOpenFilesPath: onOpenFilesPath,
                        ),
                      ),
                    ),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.database,
                    iconColor: CupertinoColors.systemPurple,
                    title: l10n.more_databaseTitle,
                    subtitle: l10n.more_databaseSubtitle,
                    onTap: () => showDatabaseSheet(context, serverId),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SubMenuCard(
                title: l10n.more_operations,
                children: [
                  SubMenuRow(
                    icon: TablerIcons.clock,
                    iconColor: CupertinoColors.systemOrange,
                    title: l10n.more_cronjobTitle,
                    subtitle: l10n.more_cronjobSubtitle,
                    onTap: () => openCronjobPage(context, serverId),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.settings,
                    iconColor: CupertinoColors.systemGrey,
                    title: l10n.more_panelSettingsTitle,
                    subtitle: l10n.more_panelSettingsSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => PanelSettingsPage(serverId: serverId),
                      ),
                    ),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.file_text,
                    iconColor: CupertinoColors.systemBrown,
                    title: l10n.log_hubTitle,
                    subtitle: l10n.more_logAuditSubtitle,
                    onTap: () => openLogHubPage(context, serverId),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SubMenuCard(
                title: l10n.more_system,
                children: [
                  // SubMenuRow(
                  //   icon: TablerIcons.chart_bar,
                  //   iconColor: CupertinoColors.systemRed,
                  //   title: '监控',
                  //   subtitle: '系统资源占用、网络流量与负载监控',
                  //   onTap: () {},
                  // ),
                  SubMenuRow(
                    icon: TablerIcons.shield_lock,
                    iconColor: CupertinoColors.systemYellow,
                    title: l10n.more_firewallTitle,
                    subtitle: l10n.more_firewallSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => FirewallPage(serverId: serverId),
                      ),
                    ),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.cpu,
                    iconColor: CupertinoColors.systemPink,
                    title: l10n.process_title,
                    subtitle: l10n.more_processSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => ProcessPage(serverId: serverId),
                      ),
                    ),
                  ),
                  SubMenuRow(
                    icon: TablerIcons.key,
                    iconColor: CupertinoColors.systemGrey2,
                    title: l10n.more_sshTitle,
                    subtitle: l10n.more_sshSubtitle,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => SshPage(serverId: serverId),
                      ),
                    ),
                  ),
                  // SubMenuRow(
                  //   icon: TablerIcons.device_floppy,
                  //   iconColor: CupertinoColors.systemBlue,
                  //   title: '磁盘管理',
                  //   subtitle: '管理磁盘分区、挂载点与磁盘扩容',
                  //   onTap: () => Navigator.of(context).push(
                  //     CupertinoPageRoute<void>(
                  //       builder: (_) => DiskPage(serverId: serverId),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
