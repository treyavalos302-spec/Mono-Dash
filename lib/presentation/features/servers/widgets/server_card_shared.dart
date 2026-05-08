import '../../../../domain/entities/dashboard.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class ServerCardStatus {
  const ServerCardStatus({
    required this.isLoading,
    required this.hasData,
    this.latencyMs,
  });

  factory ServerCardStatus.fromSnapshot({
    required bool isLoading,
    required bool hasData,
    int? latencyMs,
  }) {
    return ServerCardStatus(
      isLoading: isLoading && !hasData,
      hasData: hasData,
      latencyMs: latencyMs,
    );
  }

  final bool isLoading;
  final bool hasData;
  final int? latencyMs;

  String get terminalLabel => hasData ? 'online' : 'unknown';
  String simpleLabel(AppLocalizations l10n) =>
      hasData ? l10n.servers_online : l10n.common_unknown;
}

DiskUsage? primaryDisk(List<DiskUsage> disks) {
  if (disks.isEmpty) return null;
  for (final disk in disks) {
    if (disk.path == '/') return disk;
  }
  return disks.first;
}

String serverSubtitle({
  required String distro,
  required String ip,
  required String fallback,
}) {
  final parts = [if (distro.isNotEmpty) distro, if (ip.isNotEmpty) ip];
  if (parts.isEmpty && fallback.isNotEmpty) return fallback;
  return parts.join('  |  ');
}

String osAsset(DashboardBase? base) {
  final source = [
    base?.prettyDistro,
    base?.platform,
    base?.platformFamily,
    base?.os,
  ].whereType<String>().join(' ').toLowerCase();

  if (source.contains('ubuntu')) return 'assets/icons/os/Ubuntu.svg';
  if (source.contains('debian')) return 'assets/icons/os/Debian.svg';
  if (source.contains('centos')) return 'assets/icons/os/CentOS.svg';
  if (source.contains('fedora')) return 'assets/icons/os/Fedora.svg';
  if (source.contains('arch')) return 'assets/icons/os/Arch Linux.svg';
  if (source.contains('suse')) return 'assets/icons/os/openSUSE.svg';
  return 'assets/icons/os/Linux.svg';
}

String formatPercent(double value) {
  final clamped = value.clamp(0, 100).toDouble();
  final digits = clamped >= 10 ? 0 : 1;
  return '${clamped.toStringAsFixed(digits)}%';
}

String formatUptime(int seconds) {
  if (seconds <= 0) return 'starting';
  final days = seconds ~/ Duration.secondsPerDay;
  final hours = (seconds % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h';
  final minutes = seconds ~/ Duration.secondsPerMinute;
  return '${minutes}m';
}
