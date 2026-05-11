import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../common/components/wave_progress_item.dart';

enum UploadStatus { pending, uploading, success, failed, cancelled }

class UploadTask {
  UploadTask({required this.filePath, required this.fileSize})
    : fileName = filePath.split('/').last,
      liveActivityId =
          'upload_${DateTime.now().microsecondsSinceEpoch}_${filePath.hashCode}',
      cancelToken = CancelToken();

  final String filePath;
  final String fileName;
  final String liveActivityId;
  final int fileSize;
  final CancelToken cancelToken;

  UploadStatus status = UploadStatus.pending;
  double progress = 0.0;
  double speed = 0.0; // 字节/秒
  int lastSent = 0;
  DateTime lastTime = DateTime.now();
  DateTime lastLiveActivityUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  String? errorMessage;

  bool get isDone =>
      status == UploadStatus.success ||
      status == UploadStatus.failed ||
      status == UploadStatus.cancelled;
}

class UploadTaskItem extends StatefulWidget {
  const UploadTaskItem({
    super.key,
    required this.task,
    required this.isLast,
    required this.content,
  });

  final UploadTask task;
  final bool isLast;
  final Widget content;

  @override
  State<UploadTaskItem> createState() => _UploadTaskItemState();
}

class _UploadTaskItemState extends State<UploadTaskItem> {
  bool _showWave = true;
  Timer? _fadeOutTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void didUpdateWidget(UploadTaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkStatus();
  }

  void _checkStatus() {
    if (widget.task.status == UploadStatus.success && _fadeOutTimer == null) {
      _fadeOutTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showWave = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeOutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.task.status;
    final progress = widget.task.progress;
    final isUploading = status == UploadStatus.uploading;
    final isSuccess = status == UploadStatus.success;

    final accentColor = CupertinoColors.systemGreen.resolveFrom(context);

    return Column(
      children: [
        Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: AppColors.secondaryBackground(
                  context,
                ).withValues(alpha: 0.5),
              ),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showWave && (isUploading || isSuccess) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: WaveProgressLayer(
                  progress: progress,
                  color: accentColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            widget.content,
          ],
        ),
        if (!widget.isLast)
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: 54),
            color: AppColors.separator(context).withValues(alpha: 0.1),
          ),
      ],
    );
  }
}
