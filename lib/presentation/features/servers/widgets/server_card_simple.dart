import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../domain/entities/dashboard.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/components/skeleton_item.dart';
import '../../app_store/screens/app_store_page.dart';
import '../../cronjobs/screens/cronjob_page.dart';
import '../../databases/screens/database_page.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../../server_detail/screens/server_detail_page.dart';
import 'server_card_shared.dart';

class SimpleServerCard extends StatelessWidget {
  const SimpleServerCard({
    super.key,
    required this.server,
    required this.dashboard,
    required this.status,
    required this.onTap,
    required this.isSelected,
    this.loading = false,
  });

  final Server server;
  final Dashboard? dashboard;
  final ServerCardStatus status;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final base = dashboard?.base;
    final current = dashboard?.current;
    final disk = current == null ? null : primaryDisk(current.disks);
    final title = server.name?.isNotEmpty == true
        ? server.name!
        : (base?.hostname.isNotEmpty == true
              ? base!.hostname
              : server.displayName);
    final subtitle = base == null
        ? '${server.host}:${server.port}'
        : serverSubtitle(
            distro: base.prettyDistro,
            ip: base.ipV4Addr,
            fallback: base.platform,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _SimpleCardColors.background(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? _SimpleCardColors.selectedBorder(context)
              : _SimpleCardColors.border(context),
          width: isSelected ? 1.1 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _SimpleCardColors.shadow(context),
            blurRadius: _SimpleCardColors.isDark(context) ? 8 : 14,
            offset: Offset(0, _SimpleCardColors.isDark(context) ? 2 : 5),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(14),
        onPressed: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SimpleHeader(
                base: base,
                title: title,
                subtitle: subtitle,
                status: status,
                loading: loading,
              ),
              const SizedBox(height: 18),
              _SimpleResourceRow(
                cpuPercent: current?.cpuUsedPercent,
                memoryPercent: current?.memoryUsedPercent,
                diskPercent: disk?.usedPercent,
                loading: loading,
              ),
              const SizedBox(height: 16),
              const _SimpleDivider(),
              const SizedBox(height: 13),
              _SimpleCountRow(
                base: base,
                loading: loading,
                onWebsitesTap: () => _openWebsitesPage(context),
                onDatabasesTap: () => showDatabaseSheet(context, server.id),
                onAppsTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => AppStorePage(serverId: server.id),
                  ),
                ),
                onTasksTap: () => openCronjobPage(context, server.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWebsitesPage(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [activeServerIdProvider.overrideWithValue(server.id)],
          child: const ServerDetailPage(initialIndex: 1),
        ),
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  const _SimpleHeader({
    required this.base,
    required this.title,
    required this.subtitle,
    required this.status,
    this.loading = false,
  });

  final DashboardBase? base;
  final String title;
  final String subtitle;
  final ServerCardStatus status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (loading)
          const SkeletonItem(width: 38, height: 38, borderRadius: 10)
        else
          _SimpleOsIcon(base: base),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const SkeletonItem.text(width: 120, height: 17)
              else
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _SimpleCardColors.title(context),
                    height: 1.14,
                  ),
                ),
              const SizedBox(height: 4),
              if (loading)
                const SkeletonItem.text(width: 160, height: 12)
              else
                Text(
                  subtitle.isEmpty ? '--' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _SimpleCardColors.subtitle(context),
                    height: 1.16,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (loading)
          const SkeletonItem(width: 68, height: 24, borderRadius: 6)
        else
          _SimpleStatusPill(status: status),
      ],
    );
  }
}

class _SimpleOsIcon extends StatelessWidget {
  const _SimpleOsIcon({required this.base});

  final DashboardBase? base;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: SvgPicture.asset(osAsset(base), fit: BoxFit.contain),
    );
  }
}

class _SimpleStatusPill extends StatelessWidget {
  const _SimpleStatusPill({required this.status});

  final ServerCardStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.isLoading) {
      return const CupertinoActivityIndicator(radius: 8);
    }

    final latencyMs = status.latencyMs;
    if (status.hasData && latencyMs != null) {
      final isSlow = latencyMs > 500;
      final color = isSlow
          ? CupertinoColors.systemOrange.resolveFrom(context)
          : CupertinoColors.systemGreen.resolveFrom(context);

      return Container(
        width: 68,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.activity_heartbeat, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              '${latencyMs}ms',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.hasData
            ? _SimpleCardColors.onlineBackground(context)
            : _SimpleCardColors.unknownBackground(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.simpleLabel(context.l10n),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: status.hasData
              ? _SimpleCardColors.online(context)
              : _SimpleCardColors.unknown(context),
          height: 1,
        ),
      ),
    );
  }
}

class _SimpleResourceRow extends StatelessWidget {
  const _SimpleResourceRow({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercent,
    this.loading = false,
  });

  final double? cpuPercent;
  final double? memoryPercent;
  final double? diskPercent;
  final bool loading;

  Color _getUsageColor(BuildContext context, double? percent) {
    if (percent == null) return _SimpleCardColors.safe(context);
    if (percent >= 85) return _SimpleCardColors.critical(context);
    if (percent >= 60) return _SimpleCardColors.warning(context);
    return _SimpleCardColors.safe(context);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SimpleMetric(
            label: 'CPU',
            percent: cpuPercent,
            color: _getUsageColor(context, cpuPercent),
            loading: loading,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SimpleMetric(
            label: context.l10n.servers_memory,
            percent: memoryPercent,
            color: _getUsageColor(context, memoryPercent),
            loading: loading,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SimpleMetric(
            label: context.l10n.servers_disk,
            percent: diskPercent,
            color: _getUsageColor(context, diskPercent),
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _SimpleMetric extends StatelessWidget {
  const _SimpleMetric({
    required this.label,
    required this.percent,
    required this.color,
    this.loading = false,
  });

  final String label;
  final double? percent;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final clamped = percent?.clamp(0, 100).toDouble();
    final value = clamped == null ? '--' : formatPercent(clamped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _SimpleCardColors.metricLabel(context),
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (loading)
              const SkeletonItem.text(width: 28, height: 14)
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _SimpleCardColors.title(context),
                  height: 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            color: _SimpleCardColors.track(context),
            alignment: Alignment.centerLeft,
            child: loading
                ? null
                : TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: (clamped ?? 0) / 100),
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        widthFactor: value,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          color: color,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _SimpleDivider extends StatelessWidget {
  const _SimpleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _SimpleCardColors.divider(context));
  }
}

class _SimpleCountRow extends StatelessWidget {
  const _SimpleCountRow({
    required this.base,
    this.loading = false,
    this.onWebsitesTap,
    this.onDatabasesTap,
    this.onAppsTap,
    this.onTasksTap,
  });

  final DashboardBase? base;
  final bool loading;
  final VoidCallback? onWebsitesTap;
  final VoidCallback? onDatabasesTap;
  final VoidCallback? onAppsTap;
  final VoidCallback? onTasksTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SimpleCountItem(
          icon: TablerIcons.world,
          label: context.l10n.servers_websites,
          value: base?.websiteNumber,
          loading: loading,
          onTap: onWebsitesTap,
        ),
        _SimpleCountItem(
          icon: TablerIcons.database,
          label: context.l10n.servers_databases,
          value: base?.databaseNumber,
          loading: loading,
          onTap: onDatabasesTap,
        ),
        _SimpleCountItem(
          icon: TablerIcons.apps,
          label: context.l10n.servers_apps,
          value: base?.appInstalledNumber,
          loading: loading,
          onTap: onAppsTap,
        ),
        _SimpleCountItem(
          icon: TablerIcons.calendar_time,
          label: context.l10n.servers_tasks,
          value: base?.cronjobNumber,
          loading: loading,
          onTap: onTasksTap,
        ),
      ],
    );
  }
}

class _SimpleCountItem extends StatelessWidget {
  const _SimpleCountItem({
    required this.icon,
    required this.label,
    required this.value,
    this.loading = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int? value;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: _SimpleCardColors.countIcon(context)),
        const SizedBox(width: 5),
        if (loading)
          const SkeletonItem.text(width: 24, height: 11)
        else
          Text(
            '$label ${value ?? '--'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _SimpleCardColors.countText(context),
            ),
          ),
      ],
    );

    if (loading || onTap == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class _SimpleCardColors {
  static bool isDark(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF30343B) : const Color(0xFFE9EDF2);

  static Color selectedBorder(BuildContext context) => isDark(context)
      ? CupertinoColors.activeBlue.resolveFrom(context)
      : const Color(0xFF90CAF9);

  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2F36) : const Color(0xFFF0F2F5);

  static Color shadow(BuildContext context) =>
      CupertinoColors.black.withValues(alpha: isDark(context) ? 0.18 : 0.04);

  static Color title(BuildContext context) =>
      CupertinoColors.label.resolveFrom(context);

  static Color subtitle(BuildContext context) =>
      CupertinoColors.secondaryLabel.resolveFrom(context);

  static Color metricLabel(BuildContext context) =>
      isDark(context) ? const Color(0xFFAAB2BF) : const Color(0xFF344054);

  static Color countText(BuildContext context) =>
      isDark(context) ? const Color(0xFFB7BFCC) : const Color(0xFF475467);

  static Color countIcon(BuildContext context) =>
      isDark(context) ? const Color(0xFF98A2B3) : const Color(0xFF667085);

  static Color track(BuildContext context) =>
      isDark(context) ? const Color(0xFF303640) : const Color(0xFFE4E7EC);

  static Color safe(BuildContext context) =>
      isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);

  static Color warning(BuildContext context) =>
      isDark(context) ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  static Color critical(BuildContext context) =>
      isDark(context) ? const Color(0xFFF87171) : const Color(0xFFE11D23);

  static Color online(BuildContext context) =>
      isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF16803A);

  static Color onlineBackground(BuildContext context) =>
      online(context).withValues(alpha: isDark(context) ? 0.16 : 0.14);

  static Color unknown(BuildContext context) =>
      isDark(context) ? const Color(0xFFFBBF24) : const Color(0xFFB54708);

  static Color unknownBackground(BuildContext context) =>
      unknown(context).withValues(alpha: isDark(context) ? 0.18 : 0.14);
}
