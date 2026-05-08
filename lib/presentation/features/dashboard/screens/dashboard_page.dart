import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_content.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../../servers/providers/servers_provider.dart';

/// 概览 Tab：展示关键主机状态与实时监控。
///
/// 实时时钟通过 [ValueNotifier] 驱动，仅图表绑定订阅，避免整页 60Hz 重建。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with SingleTickerProviderStateMixin {
  static const _pollInterval = Duration(seconds: 1);

  final _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
  late final Ticker _ticker;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      _nowNotifier.value = DateTime.now();
    });
    _ticker.start();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => _refreshCurrentIfActive(),
    );
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _refreshCurrentIfActive();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ticker.dispose();
    _nowNotifier.dispose();
    super.dispose();
  }

  void _refreshCurrentIfActive() {
    if (!mounted || !widget.isActive) return;
    ref.read(dashboardControllerProvider.notifier).refreshCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(dashboardControllerProvider);

    final serversAsync = ref.watch(serversNotifierProvider);
    final activeServerId = ref.watch(activeServerIdProvider);
    final base = asyncData.valueOrNull?.dashboard.base;
    final displayName = serversAsync.maybeWhen(
      data: (servers) {
        final server = servers.firstWhere((s) => s.id == activeServerId);
        return server.name?.isNotEmpty == true
            ? server.name!
            : (base?.hostname.isNotEmpty == true
                  ? base!.hostname
                  : server.displayName);
      },
      orElse: () => null,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: FrostedScaffold.contentTopPadding(context) + 8,
          ),
        ),
        CupertinoSliverRefreshControl(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
        ),
        asyncData.when(
          data: (data) => DashboardContent(
            state: data,
            displayName: displayName,
            nowNotifier: _nowNotifier,
          ),
          loading: () => DashboardContent(
            state: DashboardViewState.dummy(),
            displayName: displayName,
            nowNotifier: _nowNotifier,
            loading: true,
          ),
          error: (err, _) => _ErrorSliver(
            error: err,
            onRetry: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
          ),
        ),
      ],
    );
  }
}

class _ErrorSliver extends StatelessWidget {
  const _ErrorSliver({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: AppErrorState(
        title: context.l10n.dashboard_loadFailed,
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}
