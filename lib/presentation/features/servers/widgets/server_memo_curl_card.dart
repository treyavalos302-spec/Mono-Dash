import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/server.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../providers/servers_provider.dart';
import 'server_card.dart';

const _pageCurlShaderAsset = 'assets/shaders/riveo_page_curl.frag';

class ServerMemoCurlCard extends ConsumerStatefulWidget {
  const ServerMemoCurlCard({
    super.key,
    required this.server,
    required this.style,
    this.onTap,
    this.isSelected = false,
    this.enabled = true,
  });

  final Server server;
  final ServerCardStyle style;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool enabled;

  @override
  ConsumerState<ServerMemoCurlCard> createState() => _ServerMemoCurlCardState();
}

class _ServerMemoCurlCardState extends ConsumerState<ServerMemoCurlCard> {
  double _drag = 0;
  double _maxDrag = 1;
  bool _sheetOpening = false;

  double get _progress => (_drag / _maxDrag).clamp(0, 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final memoAsync = ref.watch(serverMemoControllerProvider(widget.server.id));
    final frontCard = ServerCard(
      server: widget.server,
      style: widget.style,
      onTap: widget.onTap,
      isSelected: widget.isSelected,
    );

    if (!widget.enabled) return frontCard;

    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = math.max(1, constraints.maxWidth * 0.86);
        final progress = _progress;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _drag = (_drag - details.delta.dx).clamp(0, _maxDrag);
            });
          },
          onHorizontalDragEnd: (_) => _finishDrag(),
          onHorizontalDragCancel: _resetDrag,
          child: Stack(
            children: [
              Positioned.fill(
                child: _MemoBackPanel(
                  memoAsync: memoAsync,
                  onEdit: _openMemoSheet,
                ),
              ),
              IgnorePointer(
                ignoring: progress > 0.55,
                child: _PageCurlShader(
                  progress: progress,
                  cornerRadius: 14,
                  child: frontCard,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _finishDrag() {
    if (_progress >= 0.76) {
      _openMemoSheet();
      return;
    }
    _resetDrag();
  }

  void _resetDrag() {
    if (!mounted) return;
    setState(() => _drag = 0);
  }

  Future<void> _openMemoSheet() async {
    if (_sheetOpening) return;
    _sheetOpening = true;
    _resetDrag();
    try {
      await showServerMemoSheet(context, server: widget.server);
    } finally {
      _sheetOpening = false;
    }
  }
}

class _PageCurlShader extends StatelessWidget {
  const _PageCurlShader({
    required this.progress,
    required this.cornerRadius,
    required this.child,
  });

  final double progress;
  final double cornerRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderBuilder(
      (context, shader, child) {
        return AnimatedSampler(enabled: progress > 0.001, (
          ui.Image image,
          Size size,
          Canvas canvas,
        ) {
          final clamped = progress.clamp(0, 1).toDouble();
          shader
            ..setFloat(0, size.width)
            ..setFloat(1, size.height)
            ..setFloat(2, size.width * (1 - clamped))
            ..setFloat(3, size.width)
            ..setFloat(4, 0)
            ..setFloat(5, 0)
            ..setFloat(6, size.width)
            ..setFloat(7, size.height)
            ..setFloat(8, cornerRadius)
            ..setImageSampler(0, image);
          canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
        }, child: child ?? const SizedBox.shrink());
      },
      assetKey: _pageCurlShaderAsset,
      child: child,
    );
  }
}

class _MemoBackPanel extends StatelessWidget {
  const _MemoBackPanel({required this.memoAsync, required this.onEdit});

  final AsyncValue<String> memoAsync;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoColors.activeBlue.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.16),
          width: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(TablerIcons.note, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.servers_memo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.label(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      onPressed: onEdit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.edit, size: 14, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.servers_editMemo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _MemoPreview(memoAsync: memoAsync)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoPreview extends StatelessWidget {
  const _MemoPreview({required this.memoAsync});

  final AsyncValue<String> memoAsync;

  @override
  Widget build(BuildContext context) {
    final text = memoAsync.when(
      data: (memo) =>
          memo.trim().isEmpty ? context.l10n.servers_noMemo : memo.trim(),
      loading: () => context.l10n.servers_loadingMemo,
      error: (_, _) => context.l10n.servers_memoUnavailable,
    );
    final color = memoAsync.hasError
        ? CupertinoColors.systemRed.resolveFrom(context)
        : AppColors.secondaryLabel(context);

    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 5,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.24,
        color: color,
      ),
    );
  }
}

Future<void> showServerMemoSheet(
  BuildContext context, {
  required Server server,
}) {
  return showActionSheet<void>(
    context: context,
    useRootNavigator: true,
    expand: true,
    builder: (_) => _ServerMemoSheet(server: server),
  );
}

class _ServerMemoSheet extends ConsumerStatefulWidget {
  const _ServerMemoSheet({required this.server});

  final Server server;

  @override
  ConsumerState<_ServerMemoSheet> createState() => _ServerMemoSheetState();
}

class _ServerMemoSheetState extends ConsumerState<_ServerMemoSheet> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoAsync = ref.watch(serverMemoControllerProvider(widget.server.id));
    final memo = memoAsync.valueOrNull;
    if (!_initialized && memo != null) {
      _controller.text = memo;
      _initialized = true;
    }

    return ActionSheetScaffold(
      title: context.l10n.servers_editMemo,
      maxHeightFactor: 0.9,
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      trailing: CupertinoButton(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        onPressed: _saving || memoAsync.isLoading ? null : _save,
        child: _saving
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(context.l10n.common_save),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.server.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 12),
          if (memoAsync.hasError && !_initialized)
            _MemoError(
              message: memoAsync.error.toString(),
              onRetry: () => ref
                  .read(serverMemoControllerProvider(widget.server.id).notifier)
                  .refresh(),
            )
          else
            _MemoEditor(controller: _controller),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(serverMemoControllerProvider(widget.server.id).notifier)
          .save(_controller.text);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      showAppSuccessToast(context.l10n.common_saved);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showAppErrorToast(
        context.l10n.common_saveFailedCopyDetails,
        description: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MemoEditor extends StatelessWidget {
  const _MemoEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: 0.14),
          width: 0.6,
        ),
      ),
      child: CupertinoTextField(
        controller: controller,
        minLines: 14,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        padding: const EdgeInsets.all(14),
        placeholder: context.l10n.servers_memoPlaceholder,
        decoration: null,
        style: TextStyle(
          fontSize: 15,
          height: 1.35,
          color: AppColors.label(context),
        ),
        placeholderStyle: TextStyle(
          fontSize: 15,
          color: AppColors.tertiaryLabel(context),
        ),
      ),
    );
  }
}

class _MemoError extends StatelessWidget {
  const _MemoError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed
            .resolveFrom(context)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.servers_memoLoadFailed,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: CupertinoColors.systemRed.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
            onPressed: onRetry,
            child: Text(context.l10n.servers_retry),
          ),
        ],
      ),
    );
  }
}
