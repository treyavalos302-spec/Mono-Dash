import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/features/server_detail/providers/active_server_provider.dart';
import '../../presentation/features/server_detail/screens/server_detail_page.dart';
import '../../presentation/features/servers/screens/servers_page.dart';
import 'sheet_route_tracker.dart';

final routeObserver = RouteObserver<ModalRoute>();

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 全局路由配置。
///
/// 路由表：
/// - `/`              面板列表
/// - `/server/:id`    面板详情（内部 5 Tab）
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  observers: [sheetRouteTracker, routeObserver],
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ServersPage(),
    ),
    GoRoute(
      path: '/server/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id']!;
        final id = int.tryParse(idStr) ?? 0;
        return ProviderScope(
          overrides: [
            activeServerIdProvider.overrideWithValue(id),
          ],
          child: const ServerDetailPage(),
        );
      },
    ),
  ],
);
