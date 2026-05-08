import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../data/repositories_impl/file_repository_impl.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/frosted_action_popup_menu.dart';
import '../../../common/components/frosted_overlay_menu.dart';
import '../../../common/components/overlay_menu_mixin.dart';
import '../providers/files_provider.dart';
import 'upload_task_item.dart';

Future<bool> showFileUploadSheet(
  BuildContext context,
  String targetPath, {
  List<PlatformFile>? initialFiles,
}) async {
  bool hasUploaded = false;
  await showActionSheet(
    context: context,
    builder: (ctx) =>
        FileUploadSheet(targetPath: targetPath, initialFiles: initialFiles),
  );
  return hasUploaded;
}

class FileUploadSheet extends ConsumerStatefulWidget {
  const FileUploadSheet({
    super.key,
    required this.targetPath,
    this.initialFiles,
  });

  final String targetPath;
  final List<PlatformFile>? initialFiles;

  @override
  ConsumerState<FileUploadSheet> createState() => _FileUploadSheetState();
}

class _FileUploadSheetState extends ConsumerState<FileUploadSheet>
    with OverlayMenuMixin {
  final List<UploadTask> _tasks = [];
  bool _isUploading = false;
  bool _didUploadAny = false;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      final tasks = widget.initialFiles!
          .where((f) => f.path != null)
          .map((f) => UploadTask(filePath: f.path!, fileSize: f.size))
          .toList();
      _tasks.addAll(tasks);
    }
  }

  @override
  void dispose() {
    for (final task in _tasks) {
      if (!task.isDone) task.cancelToken.cancel('sheet closed');
    }
    super.dispose();
  }

  Future<void> _pickFiles(FileType type) async {
    final result = await FilePicker.pickFiles(allowMultiple: true, type: type);
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final newTasks = result.files
        .where((f) => f.path != null)
        .map((f) => UploadTask(filePath: f.path!, fileSize: f.size))
        .toList();

    final startIndex = _tasks.length;
    setState(() {
      _tasks.addAll(newTasks);
    });

    // 逐个触发插入动画
    for (int i = 0; i < newTasks.length; i++) {
      _listKey.currentState?.insertItem(
        startIndex + i,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<void> _startAllPending() async {
    final pendingTasks = _tasks
        .where((t) => t.status == UploadStatus.pending)
        .toList();
    if (pendingTasks.isEmpty) return;
    await _startUpload(pendingTasks);
  }

  Future<void> _startUpload(List<UploadTask> tasks) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    final repo = await ref.read(fileRepositoryProvider.future);
    for (final task in tasks) {
      if (!mounted || task.cancelToken.isCancelled) {
        if (mounted) setState(() => task.status = UploadStatus.cancelled);
        continue;
      }

      setState(() {
        task.status = UploadStatus.uploading;
        task.progress = 0.0;
      });

      try {
        await repo.uploadFile(
          filePath: task.filePath,
          targetPath: widget.targetPath,
          overwrite: true,
          onProgress: (p) {
            if (mounted) {
              final now = DateTime.now();
              final duration = now.difference(task.lastTime).inMilliseconds;

              if (duration >= 500) {
                final currentSent = (p * task.fileSize).toInt();
                final sentDiff = currentSent - task.lastSent;
                task.speed = (sentDiff / (duration / 1000.0));
                task.lastSent = currentSent;
                task.lastTime = now;
              }

              setState(() => task.progress = p);
            }
          },
          cancelToken: task.cancelToken,
        );
        if (mounted) {
          setState(() {
            task.status = UploadStatus.success;
            task.progress = 1.0;
            _didUploadAny = true;
          });
        }
      } on DioException catch (e) {
        if (mounted) {
          setState(() {
            task.status = e.type == DioExceptionType.cancel
                ? UploadStatus.cancelled
                : UploadStatus.failed;
            task.errorMessage = e.message;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            task.status = UploadStatus.failed;
            task.errorMessage = e.toString();
          });
        }
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  void _cancelTask(UploadTask task) {
    task.cancelToken.cancel('user cancelled');
    setState(() => task.status = UploadStatus.cancelled);
  }

  void _retryTask(UploadTask task) {
    final newTask = UploadTask(
      filePath: task.filePath,
      fileSize: task.fileSize,
    );
    final index = _tasks.indexOf(task);
    setState(() => _tasks[index] = newTask);
    _startUpload([newTask]);
  }

  // 记录哪些任务正处于点击一次后的"待确认删除"状态
  final Set<UploadTask> _confirmingTasks = {};

  void _removeTask(UploadTask task) {
    if (_confirmingTasks.contains(task)) {
      final index = _tasks.indexOf(task);
      if (index != -1) {
        final removedTask = _tasks.removeAt(index);
        _confirmingTasks.remove(task);

        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildTaskItemWrapper(
            removedTask,
            index == _tasks.length,
            animation,
          ),
          duration: const Duration(milliseconds: 300),
        );
        setState(() {});
      }
    } else {
      setState(() {
        // 先清除其他正在确认的任务（保持只有一个在确认）
        _confirmingTasks.clear();
        _confirmingTasks.add(task);
      });
    }
  }

  void _close() {
    if (_didUploadAny) {
      ref.read(filesControllerProvider.notifier).refresh();
    }
    Navigator.of(context).pop();
  }

  bool get _allDone => _tasks.isNotEmpty && _tasks.every((t) => t.isDone);

  @override
  Widget build(BuildContext context) {
    final successCount = _tasks
        .where((t) => t.status == UploadStatus.success)
        .length;
    final failCount = _tasks
        .where((t) => t.status == UploadStatus.failed)
        .length;

    return ActionSheetScaffold(
      showHandle: false,
      isAdaptive: true,
      isFloating: false,
      hasHorizontalPadding: false,
      backgroundColor: AppColors.secondaryBackground(context),
      backgroundAlpha: 1.0,
      contentPadding: const EdgeInsets.only(bottom: 30),
      panelHeader: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧大图标 (极简风格)
            Icon(
              TablerIcons.device_tablet_up,
              size: 32, // 稍微加大一点，弥补失去背景后的视觉分量
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 16),
            // 右侧文字区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.upload_title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.label(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.upload_targetPath(widget.targetPath),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryLabel(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_allDone)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _close,
                child: Text(
                  failCount > 0 && successCount == 0
                      ? context.l10n.common_close
                      : context.l10n.common_done,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              )
            else if (_isUploading)
              const CupertinoActivityIndicator(radius: 9)
            else
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _tasks.isEmpty ? null : _startAllPending,
                child: Text(
                  context.l10n.upload_startAction,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _tasks.isEmpty
                        ? AppColors.tertiaryLabel(
                            context,
                          ).withValues(alpha: 0.3)
                        : CupertinoColors.activeBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_confirmingTasks.isNotEmpty) {
            setState(() => _confirmingTasks.clear());
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // 使用 Stack 叠加空状态和列表
            Stack(
              children: [
                if (_tasks.isEmpty) _buildEmptyPrompt(),
                AnimatedList(
                  key: _listKey,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  initialItemCount: _tasks.length,
                  itemBuilder: (context, index, animation) {
                    final isLastInList = index == _tasks.length - 1;
                    final showAddButton = !_isUploading;
                    final isTrulyLast = isLastInList && !showAddButton;

                    return _buildTaskItemWrapper(
                      _tasks[index],
                      isTrulyLast,
                      animation,
                    );
                  },
                ),
              ],
            ),

            // 始终显示底部状态/添加按钮，因为它现在兼具进度条功能
            _buildAddMoreButton(),

            const SizedBox(height: 12),
            Center(
              child: Text(
                context.l10n.upload_overwriteHint,
                style: TextStyle(
                  fontSize: 10, // 进一步缩小
                  color: AppColors.tertiaryLabel(
                    context,
                  ).withValues(alpha: 0.4),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 封装动画层
  Widget _buildTaskItemWrapper(
    UploadTask task,
    bool isLast,
    Animation<double> animation,
  ) {
    // 智能动画：如果任务列表已经为空，说明这是最后一个被移除的项目。
    // 由于"空状态行"和"列表行"高度一致，此时跳过高度收缩动画，
    // 只做淡入淡出，会呈现出一种原地"内容替换"的高级感。
    if (_tasks.isEmpty) {
      return FadeTransition(
        opacity: animation,
        child: _buildTaskItem(task, isLast),
      );
    }

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: _buildTaskItem(task, isLast),
      ),
    );
  }

  void _showAddSourcePicker(BuildContext context, Offset tapOffset) {
    if (isOverlayMenuOpen) return;

    final items = [
      FrostedMenuItem(
        text: context.l10n.upload_fromAlbum,
        icon: CupertinoIcons.photo,
        action: () => _pickFiles(FileType.image),
      ),
      FrostedMenuItem(
        text: context.l10n.upload_fromFiles,
        icon: CupertinoIcons.folder,
        action: () => _pickFiles(FileType.any),
      ),
    ];

    showOverlayMenu(
      contentBuilder: (ctx) {
        const menuWidth = 180.0;
        final menuHeight = items.length * 48.0;
        final pos = OverlayMenuMixin.computeTapOffsetPosition(
          tapOffset: tapOffset,
          screenSize: MediaQuery.sizeOf(ctx),
          menuWidth: menuWidth,
          menuHeight: menuHeight,
          horizontalBias: -20,
        );
        return [
          Positioned(
            top: pos.top,
            left: pos.left,
            child: FrostedActionPopupMenu(
              width: menuWidth,
              items: items,
              alignment: pos.showAbove
                  ? Alignment.bottomLeft
                  : Alignment.topLeft,
              onSelect: (action) {
                hideOverlayMenu();
                action();
              },
            ),
          ),
        ];
      },
      dismissBuilder: (ctx, onDismiss) => Positioned.fill(
        child: GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.translucent,
        ),
      ),
    );
  }

  Widget _buildAddMoreButton() {
    Offset? lastTapOffset;

    // 计算总进度
    final totalProgress = _tasks.isEmpty
        ? 0.0
        : _tasks.fold(0.0, (sum, t) => sum + t.progress) / _tasks.length;
    final failCount = _tasks
        .where((t) => t.status == UploadStatus.failed)
        .length;
    final hasFailed = failCount > 0;
    final isDone = _allDone;

    // 状态定义
    Color accentColor = CupertinoColors.activeBlue;
    String label = context.l10n.upload_addFiles;
    IconData leadingIcon = CupertinoIcons.doc;
    Widget? trailing;

    if (_isUploading) {
      accentColor = CupertinoColors.systemGreen;
      label = context.l10n.upload_uploadingProgress(
        (totalProgress * 100).toStringAsFixed(0),
      );
      leadingIcon = TablerIcons.upload;
      trailing = const CupertinoActivityIndicator(radius: 8);
    } else if (isDone) {
      if (hasFailed) {
        accentColor = CupertinoColors.systemOrange;
        label = context.l10n.upload_partialFailedCount(failCount);
        leadingIcon = CupertinoIcons.exclamationmark_triangle_fill;
        trailing = Icon(
          CupertinoIcons.chevron_right,
          size: 14,
          color: CupertinoDynamicColor.resolve(accentColor, context),
        );
      } else {
        accentColor = CupertinoColors.systemGreen;
        label = context.l10n.upload_allComplete;
        leadingIcon = CupertinoIcons.checkmark_circle_fill;
        trailing = Icon(
          CupertinoIcons.checkmark_alt,
          size: 18,
          color: CupertinoDynamicColor.resolve(accentColor, context),
        );
      }
    } else {
      trailing = Icon(TablerIcons.plus, size: 20, color: accentColor);
    }

    return Builder(
      builder: (context) => GestureDetector(
        onTapDown: (details) => lastTapOffset = details.globalPosition,
        onTap: () {
          if (_isUploading) return; // 上传中禁止点击
          if (lastTapOffset != null) {
            _showAddSourcePicker(context, lastTapOffset!);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12,
          ),
          child: Row(
            children: [
              // 核心图标区域 (带液位填充效果)
              Stack(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: CupertinoDynamicColor.resolve(
                        accentColor,
                        context,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CupertinoDynamicColor.resolve(
                          accentColor,
                          context,
                        ).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  // 进度填充层 (从下往上)
                  if (_isUploading || isDone)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height:
                                    42 *
                                    (isDone && !hasFailed
                                        ? 1.0
                                        : totalProgress),
                                decoration: BoxDecoration(
                                  color:
                                      CupertinoDynamicColor.resolve(
                                        accentColor,
                                        context,
                                      ).withValues(
                                        alpha: isDone && !hasFailed
                                            ? 0.1
                                            : (hasFailed ? 0.2 : 0.4),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 图标层
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: Icon(
                        leadingIcon,
                        color: CupertinoDynamicColor.resolve(
                          accentColor,
                          context,
                        ),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // 文字区域
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoDynamicColor.resolve(accentColor, context),
                  ),
                ),
              ),
              // 右侧动效
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                  child: trailing,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          color: AppColors.secondaryBackground(context).withValues(alpha: 0.5),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.label(context).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CupertinoIcons.tray,
                  size: 24,
                  color: AppColors.tertiaryLabel(
                    context,
                  ).withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                context.l10n.upload_emptyPending,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 0.5,
          color: AppColors.separator(context).withValues(alpha: 0.15),
        ),
      ],
    );
  }

  Widget _buildSummary(int successCount, int failCount) {
    final isAllSuccess = failCount == 0;
    final color = isAllSuccess
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.systemOrange.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      color: color.withValues(alpha: 0.05),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAllSuccess
                  ? CupertinoIcons.checkmark_alt
                  : CupertinoIcons.exclamationmark,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAllSuccess
                ? context.l10n.upload_summaryCompleteTitle
                : context.l10n.upload_summaryPartialFailedTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.label(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAllSuccess
                ? context.l10n.upload_summarySuccessCount(successCount)
                : context.l10n.upload_summaryMixedCount(
                    successCount,
                    failCount,
                  ),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(UploadTask task, bool isLast) {
    return UploadTaskItem(
      task: task,
      isLast: isLast,
      content: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 文件图标 (更扁平)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.label(context).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _buildFileIcon(task),
            ),
            const SizedBox(width: 14),
            // 信息区
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    truncateMiddle(task.fileName, 32),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.label(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildTaskMetadata(task),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _buildActionButton(task),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(UploadTask task) {
    // 简单的类型判断以展示图标
    final ext = task.fileName.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      icon = CupertinoIcons.photo;
      color = CupertinoColors.systemPurple;
    } else if (['mp4', 'mov', 'avi'].contains(ext)) {
      icon = CupertinoIcons.video_camera;
      color = CupertinoColors.systemPink;
    } else if (['zip', 'gz', 'tar', '7z'].contains(ext)) {
      icon = TablerIcons.file_zip;
      color = CupertinoColors.systemOrange;
    } else {
      icon = CupertinoIcons.doc;
      color = CupertinoColors.systemBlue;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildStatusBadge(UploadTask task) {
    switch (task.status) {
      case UploadStatus.success:
        return const Icon(
          CupertinoIcons.checkmark_circle_fill,
          size: 14,
          color: CupertinoColors.systemGreen,
        );
      case UploadStatus.failed:
        return const Icon(
          CupertinoIcons.exclamationmark_circle_fill,
          size: 14,
          color: CupertinoColors.systemRed,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTaskMetadata(UploadTask task) {
    String text;
    Color? textColor;

    final ext = task.fileName.contains('.')
        ? task.fileName.split('.').last.toUpperCase()
        : 'FILE';

    switch (task.status) {
      case UploadStatus.uploading:
        final speedText = task.speed > 0
            ? formatByteRate(task.speed.toInt())
            : '--';
        text =
            '${(task.progress * 100).toStringAsFixed(0)}%  •  $speedText  •  $ext  •  ${formatBytes(task.fileSize)}';
        break;
      case UploadStatus.failed:
        text = task.errorMessage ?? context.l10n.upload_failed;
        textColor = CupertinoColors.systemRed;
        break;
      case UploadStatus.cancelled:
        text = context.l10n.upload_cancelled;
        break;
      default:
        text = '$ext  •  ${formatBytes(task.fileSize)}';
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: textColor ?? AppColors.secondaryLabel(context),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSlimProgressBar(UploadTask task) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: Container(
        height: 3,
        width: double.infinity,
        color: AppColors.separator(context).withValues(alpha: 0.1),
        child: UnconstrainedBox(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width:
                (MediaQuery.of(context).size.width - 100) *
                task.progress.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.resolveFrom(context),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(UploadTask task) {
    // 优先处理"待确认删除"状态
    if (_confirmingTasks.contains(task)) {
      return CupertinoButton(
        padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
        minimumSize: Size.zero,
        onPressed: () => _removeTask(task),
        child: const Icon(
          CupertinoIcons.trash_fill,
          size: 20,
          color: CupertinoColors.systemRed,
        ),
      );
    }

    switch (task.status) {
      case UploadStatus.pending:
        return CupertinoButton(
          padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
          minimumSize: Size.zero,
          onPressed: () => _removeTask(task),
          child: Icon(
            TablerIcons.x,
            size: 20,
            color: AppColors.tertiaryLabel(context).withValues(alpha: 0.4),
          ),
        );
      case UploadStatus.uploading:
        return CupertinoButton(
          padding: const EdgeInsets.all(6),
          minimumSize: Size.zero,
          onPressed: () => _cancelTask(task),
          child: Icon(
            TablerIcons.x,
            size: 16,
            color: AppColors.secondaryLabel(context),
          ),
        );
      case UploadStatus.failed:
        return CupertinoButton(
          padding: const EdgeInsets.all(6),
          minimumSize: Size.zero,
          onPressed: () => _retryTask(task),
          child: const Icon(
            TablerIcons.refresh,
            size: 16,
            color: CupertinoColors.activeBlue,
          ),
        );
      case UploadStatus.success:
        return const Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 0, 8),
          child: Icon(
            CupertinoIcons.checkmark_alt,
            size: 20,
            color: CupertinoColors.systemGreen,
          ),
        );
      case UploadStatus.cancelled:
        return CupertinoButton(
          padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
          minimumSize: Size.zero,
          onPressed: () => _removeTask(task),
          child: Icon(
            TablerIcons.x,
            size: 20,
            color: AppColors.tertiaryLabel(context).withValues(alpha: 0.2),
          ),
        );
      default:
        return const SizedBox(width: 28);
    }
  }
}
