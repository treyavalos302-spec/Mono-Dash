import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/server.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/servers_provider.dart';
import 'server_card_shared.dart';
import 'server_card_simple.dart';
import 'server_card_terminal.dart';

class ServerCard extends ConsumerWidget {
  const ServerCard({
    super.key,
    required this.server,
    this.onTap,
    this.isSelected = false,
    this.style = ServerCardStyle.simple,
  });

  final Server server;
  final VoidCallback? onTap;
  final bool isSelected;
  final ServerCardStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(serverDashboardSnapshotProvider(server.id));
    final snapshotData = snapshot.valueOrNull;
    final dashboard = snapshotData?.dashboard;
    final status = ServerCardStatus.fromSnapshot(
      isLoading: snapshot.isLoading,
      hasData: dashboard != null,
      latencyMs: snapshotData?.fetchMs,
    );

    return switch (style) {
      ServerCardStyle.simple => SimpleServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: status.isLoading && !status.hasData,
      ),
      ServerCardStyle.terminal => TerminalServerCard(
        server: server,
        dashboard: dashboard,
        status: status,
        onTap: onTap,
        isSelected: isSelected,
        loading: status.isLoading && !status.hasData,
      ),
    };
  }
}
