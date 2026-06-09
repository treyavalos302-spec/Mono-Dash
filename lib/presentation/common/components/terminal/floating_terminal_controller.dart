import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

/// 悬浮终端的完整状态快照。
///
/// 当用户点击"悬浮"时，终端屏幕将自身状态打包成此对象，
/// 交给 [FloatingTerminalController] 管理。
class FloatingTerminalState {
  FloatingTerminalState({
    String? id,
    this.bubbleSnapshot,
    required this.terminal,
    required this.terminalController,
    required this.channel,
    required this.subscription,
    required this.isConnected,
    required this.statusMessage,
    required this.title,
    required this.containerId,
    required this.user,
    required this.command,
    required this.source,
    this.databaseType,
    this.databaseName,
    required this.serverId,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  FloatingTerminalBubbleSnapshot? bubbleSnapshot;
  final Terminal terminal;
  final TerminalController terminalController;
  final WebSocketChannel? channel;
  final StreamSubscription? subscription;
  final bool isConnected;
  final String statusMessage;
  final String title;

  // 原始参数
  final String containerId;
  final String user;
  final String command;
  final String source;
  final String? databaseType;
  final String? databaseName;
  final int serverId;

  /// 关闭 WebSocket 和流订阅，释放资源。
  void dispose() {
    subscription?.cancel();
    channel?.sink.close();
    terminalController.dispose();
  }
}

class FloatingTerminalBubbleSnapshot {
  const FloatingTerminalBubbleSnapshot({
    required this.dx,
    required this.dy,
    required this.isLeft,
    required this.isDocked,
  });

  final double dx;
  final double dy;
  final bool isLeft;
  final bool isDocked;
}

/// 管理当前悬浮中的终端会话。
class FloatingTerminalController extends ChangeNotifier {
  final List<FloatingTerminalState> _states = [];

  /// 当前悬浮中的终端状态列表。
  List<FloatingTerminalState> get states => List.unmodifiable(_states);

  /// 是否有悬浮中的终端。
  bool get hasFloatingTerminal => _states.isNotEmpty;

  /// 将终端状态保存为悬浮状态。
  void floatTerminal(FloatingTerminalState state) {
    _states.add(state);
    notifyListeners();
  }

  void updateBubbleSnapshot(
    String id,
    FloatingTerminalBubbleSnapshot snapshot,
  ) {
    final index = _states.indexWhere((s) => s.id == id);
    if (index == -1) return;
    _states[index].bubbleSnapshot = snapshot;
  }

  /// 取出悬浮中的终端状态以恢复终端界面。
  /// 调用后悬浮状态被清除（气泡消失）。
  FloatingTerminalState? restoreTerminal(String id) {
    final index = _states.indexWhere((s) => s.id == id);
    if (index == -1) return null;
    final state = _states.removeAt(index);
    notifyListeners();
    return state;
  }

  /// 关闭悬浮中的终端（断开连接并释放资源）。
  void closeTerminal(String id) {
    final index = _states.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final state = _states.removeAt(index);
    state.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final state in _states) {
      state.dispose();
    }
    _states.clear();
    super.dispose();
  }
}

/// 全局悬浮终端 Provider。
final floatingTerminalProvider =
    ChangeNotifierProvider<FloatingTerminalController>((ref) {
      return FloatingTerminalController();
    });
