import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_x.dart';
import 'floating_terminal_controller.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'app_terminal.dart';

/// 悬浮终端气泡 Overlay 管理器。
///
/// 作为 Widget 插入到 app builder 中，监听 [floatingTerminalProvider]，
/// 当存在悬浮终端时用 Stack 覆盖显示一个可拖拽的终端气泡。
class FloatingTerminalOverlay extends ConsumerStatefulWidget {
  const FloatingTerminalOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FloatingTerminalOverlay> createState() =>
      _FloatingTerminalOverlayState();
}

class _FloatingTerminalOverlayState
    extends ConsumerState<FloatingTerminalOverlay> {
  void _handleRestore(String id) {
    final controller = ref.read(floatingTerminalProvider);
    final state = controller.restoreTerminal(id);
    if (state == null || !mounted) return;

    restoreAppTerminal(context, state);
  }

  void _handleClose(String id) {
    ref.read(floatingTerminalProvider).closeTerminal(id);
  }

  @override
  Widget build(BuildContext context) {
    final states = ref.watch(floatingTerminalProvider.select((c) => c.states));

    if (states.isEmpty) return widget.child;

    return Stack(
      children: [
        widget.child,
        for (final entry in states.asMap().entries)
          _FloatingTerminalBubble(
            key: ValueKey(entry.value.id),
            initialIndex: entry.key,
            initialSnapshot: entry.value.bubbleSnapshot,
            onSnapshotChanged: (snapshot) => ref
                .read(floatingTerminalProvider)
                .updateBubbleSnapshot(entry.value.id, snapshot),
            onRestore: () => _handleRestore(entry.value.id),
            onClose: () => _handleClose(entry.value.id),
          ),
      ],
    );
  }
}

/// 悬浮终端气泡组件。
///
/// 56×56 圆形气泡，融入屏幕边缘。
/// 支持：
/// - 自动吸附至边缘
/// - 闲置后半收纳进屏幕边缘，呈流体“Meniscus”水滴微突
/// - 拖动时像液滴拉伸（Stretching Bezier）从边缘脱落
/// - 脉冲呼吸流体呼吸光圈
class _FloatingTerminalBubble extends StatefulWidget {
  const _FloatingTerminalBubble({
    required this.initialIndex,
    required this.initialSnapshot,
    required this.onSnapshotChanged,
    required this.onRestore,
    required this.onClose,
    super.key,
  });

  final int initialIndex;
  final FloatingTerminalBubbleSnapshot? initialSnapshot;
  final ValueChanged<FloatingTerminalBubbleSnapshot> onSnapshotChanged;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  State<_FloatingTerminalBubble> createState() =>
      _FloatingTerminalBubbleState();
}

class _FloatingTerminalBubbleState extends State<_FloatingTerminalBubble>
    with SingleTickerProviderStateMixin {
  static const double _bubbleSize = 56.0;
  static const double _dockedVisibleWidth = 12.0;
  static const double _expandedEdgeInset = 16.0;
  static const double _detachDistance = 75.0;
  static const double _expandedVisualDistance = 96.0;
  static const double _dockedRestingDistance =
      _dockedVisibleWidth - _bubbleSize / 2;
  static const double _expandedRestingDistance =
      _expandedEdgeInset + _bubbleSize / 2;
  static const Duration _idleDockDelay = Duration(milliseconds: 3000);

  // 位置与状态
  double _dx = 0;
  double _dy = 0;
  bool _positioned = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // 缩放进入动画
  bool _appeared = false;

  // 交互状态机
  bool _isDragging = false;
  bool _isDocked = false;
  bool _isLeft = false;
  Duration _positionDuration = Duration.zero;
  Curve _positionCurve = Curves.easeOutCubic;
  Timer? _dockTimer;
  bool _isAnimating = false; // 是否正处于平移/收纳/吸边动画中
  bool _isFluidExpanding = false; // 点击收纳态展开时，保留液滴拉伸过程。

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      final initialSnapshot = widget.initialSnapshot;
      setState(() {
        final minY = padding.top + 8;
        final maxY = size.height - _bubbleSize - padding.bottom - 8;

        if (initialSnapshot != null) {
          _isLeft = initialSnapshot.isLeft;
          _isDocked = initialSnapshot.isDocked;
          if (_isDocked) {
            _dx = _isLeft
                ? -_bubbleSize + _dockedVisibleWidth
                : size.width - _dockedVisibleWidth;
          } else {
            _dx = initialSnapshot.dx.clamp(-_bubbleSize, size.width);
          }
          _dy = initialSnapshot.dy.clamp(minY, maxY);
        } else {
          final initialY =
              size.height -
              _bubbleSize -
              padding.bottom -
              100 -
              widget.initialIndex * (_bubbleSize + 12);

          // 初始位置：右下角
          _dx = size.width - _bubbleSize - 16;
          _dy = initialY.clamp(minY, maxY);
          _isLeft = false;
          _isDocked = false;
        }
        _positioned = true;
      });
      _commitSnapshot();

      // 触发缩放进入动画并紧接着开始平滑收纳
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) setState(() => _appeared = true);
      });
      if (initialSnapshot != null) {
        if (!initialSnapshot.isDocked) _startDockTimer();
        return;
      }
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || _isDragging || _isDocked) return;
        setState(() {
          _isDocked = true;
          _positionDuration = const Duration(milliseconds: 520);
          _positionCurve = Curves.easeInOutCubic;
          _dx = size.width - _dockedVisibleWidth;
          _isAnimating = true;
        });
        _commitSnapshot();
        Timer(const Duration(milliseconds: 520), () {
          if (mounted) setState(() => _isAnimating = false);
        });
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dockTimer?.cancel();
    super.dispose();
  }

  void _startDockTimer() {
    _dockTimer?.cancel();
    _dockTimer = Timer(_idleDockDelay, () {
      if (!mounted || _isDragging || _isDocked) return;
      setState(() {
        _isDocked = true;
        _positionDuration = const Duration(milliseconds: 520);
        _positionCurve = Curves.easeInOutCubic;
        _isAnimating = true;
        _isFluidExpanding = false;
        final size = MediaQuery.of(context).size;
        if (_isLeft) {
          _dx = -_bubbleSize + _dockedVisibleWidth;
        } else {
          _dx = size.width - _dockedVisibleWidth;
        }
      });
      _commitSnapshot();
      Timer(const Duration(milliseconds: 520), () {
        if (mounted) setState(() => _isAnimating = false);
      });
    });
  }

  void _cancelDockTimer() {
    _dockTimer?.cancel();
  }

  void _commitSnapshot() {
    widget.onSnapshotChanged(
      FloatingTerminalBubbleSnapshot(
        dx: _dx,
        dy: _dy,
        isLeft: _isLeft,
        isDocked: _isDocked,
      ),
    );
  }

  void _expandBubble({required double screenWidth}) {
    _isDocked = false;

    if (_isLeft) {
      _dx = _expandedEdgeInset;
    } else {
      _dx = screenWidth - _bubbleSize - _expandedEdgeInset;
    }

    _startDockTimer();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();

    if (_isDocked) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _positionDuration = const Duration(milliseconds: 420);
        _positionCurve = Curves.easeOutBack;
        _isAnimating = true;
        _isFluidExpanding = true;
        _expandBubble(screenWidth: size.width);
      });
      _commitSnapshot();
      Timer(const Duration(milliseconds: 420), () {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _isFluidExpanding = false;
          });
        }
      });
      return;
    }

    _commitSnapshot();
    widget.onRestore();
  }

  double _fluidExpandDistance(double rawDistanceFromEdge) {
    final progress =
        ((rawDistanceFromEdge - _dockedRestingDistance) /
                (_expandedRestingDistance - _dockedRestingDistance))
            .clamp(0.0, 1.0);
    final easedProgress = Curves.easeOutCubic.transform(progress);
    return _expandedVisualDistance * easedProgress;
  }

  void _onPanStart(DragStartDetails details) {
    _cancelDockTimer();
    setState(() {
      _isDragging = true;

      // 仅当气泡处于吸边或收纳动画运动中时，才将气泡中心对齐到手指触摸点，瞬间纠正坐标突跳。
      // 如果本就处于静止（包括已收纳）状态，则不进行对齐对位，防止轻微触摸时气泡从壁面弹起脱离。
      if (_isAnimating) {
        final size = MediaQuery.of(context).size;
        final padding = MediaQuery.of(context).padding;
        _dx = (details.globalPosition.dx - _bubbleSize / 2).clamp(
          -_bubbleSize,
          size.width,
        );

        final minY = padding.top + 8;
        final maxY = size.height - _bubbleSize - padding.bottom - 8;
        _dy = (details.globalPosition.dy - _bubbleSize / 2).clamp(minY, maxY);
      }

      _isAnimating = false; // 进入拖拽后，任何过渡动画应被终止并覆盖
      _isFluidExpanding = false;
      _positionDuration = Duration.zero; // 拖拽时无延迟贴合手指
      _positionCurve = Curves.linear;
    });
    _commitSnapshot();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    setState(() {
      if (_isDocked) {
        // 边缘收起状态下，沿拉伸方向阻尼形变拉出
        if (_isLeft) {
          final double dockedX = -_bubbleSize + _dockedVisibleWidth;
          final double potentialX = _dx + details.delta.dx;
          _dx = potentialX.clamp(dockedX, size.width - _bubbleSize);

          final distanceFromEdge = _dx + (_bubbleSize / 2);
          if (distanceFromEdge >= _detachDistance) {
            _isDocked = false;
            HapticFeedback.lightImpact(); // 瞬间剥离边缘时的轻微触觉反馈
          }
        } else {
          final double dockedX = size.width - _dockedVisibleWidth;
          final double potentialX = _dx + details.delta.dx;
          _dx = potentialX.clamp(-_bubbleSize, dockedX);

          final distanceFromEdge = size.width - (_dx + (_bubbleSize / 2));
          if (distanceFromEdge >= _detachDistance) {
            _isDocked = false;
            HapticFeedback.lightImpact();
          }
        }
      } else {
        // 自由浮动状态，直接跟随
        _dx += details.delta.dx;
      }

      // 允许任意状态的纵向滑动
      final minY = padding.top + 8;
      final maxY = size.height - _bubbleSize - padding.bottom - 8;
      _dy = (_dy + details.delta.dy).clamp(minY, maxY);
    });
    _commitSnapshot();
  }

  void _onPanEnd(DragEndDetails details) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    setState(() {
      _isDragging = false;
      _positionDuration = const Duration(milliseconds: 420);
      _positionCurve = Curves.easeOutBack;
      _isAnimating = true;
      _isFluidExpanding = false;

      // 若拖出距离不足以剥离壁面，则回弹收起
      if (_isDocked) {
        _positionDuration = const Duration(milliseconds: 360);
        _positionCurve = Curves.easeOutCubic;
        if (_isLeft) {
          _dx = -_bubbleSize + _dockedVisibleWidth;
        } else {
          _dx = size.width - _dockedVisibleWidth;
        }
        _commitSnapshot();
        Timer(const Duration(milliseconds: 360), () {
          if (mounted) setState(() => _isAnimating = false);
        });
        return;
      }

      // 已剥离时，拖拽的语义是展开和重新定位。
      // 松手后保持完整气泡贴边，闲置一段时间后再自动收纳。
      final centerX = _dx + _bubbleSize / 2;
      _isLeft = centerX < size.width / 2;
      _expandBubble(screenWidth: size.width);

      final minY = padding.top + 8;
      final maxY = size.height - _bubbleSize - padding.bottom - 8;
      _dy = _dy.clamp(minY, maxY);

      _commitSnapshot();
      Timer(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _isAnimating = false);
      });
    });
  }

  void _showContextMenu() {
    _cancelDockTimer();
    HapticFeedback.mediumImpact();
    final l10n = context.l10n;

    final route = CupertinoModalPopupRoute<void>(
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _commitSnapshot();
              widget.onRestore();
            },
            child: Text(l10n.terminal_floatRestore),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onClose();
            },
            child: Text(l10n.terminal_floatClose),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(ctx).pop();
            _startDockTimer();
          },
          child: Text(l10n.common_cancel),
        ),
      ),
      barrierDismissible: true,
    );

    final navigator = rootNavigatorKey.currentState;
    if (navigator != null) {
      navigator.push(route).then((_) {
        if (mounted && !_isDragging && !_isDocked) {
          _startDockTimer();
        }
      });
    } else {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _commitSnapshot();
                widget.onRestore();
              },
              child: Text(l10n.terminal_floatRestore),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onClose();
              },
              child: Text(l10n.terminal_floatClose),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startDockTimer();
            },
            child: Text(l10n.common_cancel),
          ),
        ),
      ).then((_) {
        if (mounted && !_isDragging && !_isDocked) {
          _startDockTimer();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_positioned) return const SizedBox.shrink();

    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: Offset(_dx, _dy)),
      duration: _positionDuration,
      curve: _positionCurve,
      builder: (context, position, child) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: AnimatedScale(
            scale: _appeared ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _appeared ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: GestureDetector(
                onTap: _handleTap,
                onLongPress: _showContextMenu,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final isDark =
                        CupertinoTheme.brightnessOf(context) == Brightness.dark;

                    // 黑流体材质：纯黑质感 / 轻度微光
                    final backgroundColor = isDark
                        ? const Color(0xFF0C0C0E)
                        : CupertinoColors.black;
                    final borderColor = isDark
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                        : CupertinoColors.white.withValues(alpha: 0.15);

                    final size = MediaQuery.of(context).size;
                    final centerX = position.dx + _bubbleSize / 2;
                    final rawDistanceFromEdge = _isLeft
                        ? centerX
                        : size.width - centerX;
                    final isExpandedResting =
                        !_isDocked && !_isDragging && !_isFluidExpanding;
                    final distanceFromEdge = isExpandedResting
                        ? _expandedVisualDistance
                        : _isFluidExpanding
                        ? _fluidExpandDistance(rawDistanceFromEdge)
                        : rawDistanceFromEdge;

                    // 图标只在液滴完全脱离边缘、恢复圆形后出现。
                    // 收纳和拉丝阶段的液体形态不是圆形，保留图标会显得像被单独拖出。
                    final iconProgress =
                        ((distanceFromEdge - _detachDistance) / 20.0).clamp(
                          0.0,
                          1.0,
                        );
                    final iconOpacity = Curves.easeOut.transform(iconProgress);
                    final iconScale = 0.86 + 0.14 * iconOpacity;

                    return CustomPaint(
                      size: const Size(_bubbleSize, _bubbleSize),
                      painter: FluidDockPainter(
                        isLeft: _isLeft,
                        distanceFromEdge: distanceFromEdge,
                        color: backgroundColor,
                        borderColor: borderColor,
                        isDark: isDark,
                        glowValue: _pulseAnimation.value,
                      ),
                      child: SizedBox(
                        width: _bubbleSize,
                        height: _bubbleSize,
                        child: Center(
                          child: Transform.scale(
                            scale: iconScale,
                            child: Opacity(
                              opacity: iconOpacity,
                              child: Icon(
                                TablerIcons.terminal_2,
                                size: 20,
                                color: CupertinoColors.white.withValues(
                                  alpha: 0.92,
                                ),
                                shadows: [
                                  Shadow(
                                    color: isDark
                                        ? const Color(
                                            0xFF00E5FF,
                                          ).withValues(alpha: 0.8)
                                        : CupertinoColors.activeBlue.withValues(
                                            alpha: 0.6,
                                          ),
                                    blurRadius: 8.0,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 流体边缘交互 CustomPainter
///
/// 绘制：
/// 1. 收纳时 (distanceFromEdge < 28) 的“平滑水滴 meniscus”微突
/// 2. 拉出时 (28 <= distanceFromEdge <= 75) 连结壁面的“液滴贝塞尔颈拉伸”
/// 3. 脱离后 (distanceFromEdge > 75) 还原成完美圆形
class FluidDockPainter extends CustomPainter {
  final bool isLeft;
  final double distanceFromEdge;
  final Color color;
  final Color borderColor;
  final bool isDark;
  final double glowValue;

  FluidDockPainter({
    required this.isLeft,
    required this.distanceFromEdge,
    required this.color,
    required this.borderColor,
    required this.isDark,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    const R = 28.0;
    const cy = 28.0;
    const cx = 28.0;

    if (distanceFromEdge < R) {
      // 1. 半收起形态：壁面弯月液面 (Meniscus Bump)
      final d = distanceFromEdge.clamp(0.0, R);
      final xe = isLeft ? R - d : R + d;
      final yc = math.sqrt((R * R) - (d * d));
      const fillet = 8.0; // 圆角化切线融合

      if (isLeft) {
        path.moveTo(xe, cy - yc - fillet);
        path.quadraticBezierTo(xe, cy - yc, xe + 3, cy - yc + 1);
        path.arcToPoint(
          Offset(xe + 3, cy + yc - 1),
          radius: const Radius.circular(R),
          clockwise: true,
        );
        path.quadraticBezierTo(xe, cy + yc, xe, cy + yc + fillet);
        path.close();
      } else {
        path.moveTo(xe, cy - yc - fillet);
        path.quadraticBezierTo(xe, cy - yc, xe - 3, cy - yc + 1);
        path.arcToPoint(
          Offset(xe - 3, cy + yc - 1),
          radius: const Radius.circular(R),
          clockwise: false,
        );
        path.quadraticBezierTo(xe, cy + yc, xe, cy + yc + fillet);
        path.close();
      }
    } else if (distanceFromEdge <= 75.0) {
      // 2. 拉伸形变：壁面液滴拉丝 (Fluid Neck Stretch)
      final d = distanceFromEdge;
      final xe = isLeft ? R - d : R + d;
      final progress = (d - R) / (75.0 - R);
      // 随着拉伸距离增加，壁面连结部分 (W) 越变越窄
      final W = math.max(4.0, R * (1.0 - progress));

      if (isLeft) {
        path.moveTo(xe, cy - W);
        // 上颈部贝塞尔
        path.cubicTo(xe + d * 0.35, cy - W, xe + d * 0.6, 0.0, cx, 0.0);
        // 圆头部分 (右侧半圆)
        path.arcToPoint(
          const Offset(cx, 56.0),
          radius: const Radius.circular(R),
          clockwise: true,
        );
        // 下颈部贝塞尔
        path.cubicTo(xe + d * 0.6, 56.0, xe + d * 0.35, cy + W, xe, cy + W);
        path.close();
      } else {
        path.moveTo(xe, cy - W);
        // 上颈部贝塞尔
        path.cubicTo(xe - d * 0.35, cy - W, xe - d * 0.6, 0.0, cx, 0.0);
        // 圆头部分 (左侧半圆)
        path.arcToPoint(
          const Offset(cx, 56.0),
          radius: const Radius.circular(R),
          clockwise: false,
        );
        // 下颈部贝塞尔
        path.cubicTo(xe - d * 0.6, 56.0, xe - d * 0.35, cy + W, xe, cy + W);
        path.close();
      }
    } else {
      // 3. 剥离状态：还原为标准正圆
      path.addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: R));
    }

    // 绘制流体脉冲呼吸发光
    if (isDark) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25 * glowValue)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 10.0 * glowValue);
      canvas.drawPath(path, glowPaint);
    } else {
      final glowPaint = Paint()
        ..color = CupertinoColors.activeBlue.withValues(alpha: 0.18 * glowValue)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 8.0 * glowValue);
      canvas.drawPath(path, glowPaint);
    }

    // 绘制液滴阴影
    final shadowColor = isDark
        ? CupertinoColors.black.withValues(alpha: 0.45)
        : CupertinoColors.black.withValues(alpha: 0.15);
    canvas.drawShadow(path, shadowColor, 6.0, true);

    // 填充液面
    canvas.drawPath(path, paint);

    // 描边边界线
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant FluidDockPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft ||
        oldDelegate.distanceFromEdge != distanceFromEdge ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.glowValue != glowValue;
  }
}
