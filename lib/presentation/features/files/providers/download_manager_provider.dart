import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/file_transfer_live_activity_service.dart';
import '../../../../data/api/file_api.dart';
import '../../../../data/repositories_impl/file_repository_impl.dart';
import '../../../../domain/repositories/file_repository.dart';
import '../models/download_task.dart';

part 'download_manager_provider.g.dart';

const _uuid = Uuid();
const _liveActivityUpdateInterval = Duration(seconds: 1);

@Riverpod(keepAlive: true, dependencies: [appLocalizations])
class DownloadManager extends _$DownloadManager {
  @override
  List<DownloadTask> build() {
    _loadFromDisk();
    return [];
  }

  // ---------------------------------------------------------------------------
  // 公开 API
  // ---------------------------------------------------------------------------

  Future<FileRepository> _getRepository(int serverId) async {
    final client = await ref.read(dioClientProvider(serverId).future);
    final storage = ref.read(storageServiceProvider);
    return FileRepositoryImpl(FileApi(client), storage, serverId.toString());
  }

  /// 发起新下载任务，返回任务 ID
  Future<String> startDownload({
    required int serverId,
    required String remotePath,
    required String fileName,
    required int fileSize,
  }) async {
    final baseDir = await _ensureServerDir(serverId);
    final localPath = _resolveLocalPath(baseDir, fileName);
    final taskId = _uuid.v4();

    final task = DownloadTask(
      id: taskId,
      serverId: serverId,
      remotePath: remotePath,
      fileName: fileName,
      localPath: localPath,
      fileSize: fileSize,
      createdAt: DateTime.now(),
    );
    task.cancelToken = CancelToken();

    state = [...state, task];
    _persistToDisk();
    _executeDownload(task);
    return taskId;
  }

  /// 批量打包下载（支持目录和多选）
  Future<String> startBatchPackageDownload({
    required int serverId,
    required List<String> remotePaths,
  }) async {
    final randomStr = _uuid.v4().substring(0, 8);
    final fileName = '1panel_mate_$randomStr.zip';
    final baseDir = await _ensureServerDir(serverId);
    final localPath = _resolveLocalPath(baseDir, fileName);
    final taskId = _uuid.v4();

    final task = DownloadTask(
      id: taskId,
      serverId: serverId,
      remotePath: '/tmp/$fileName',
      fileName: fileName,
      localPath: localPath,
      fileSize: 0,
      createdAt: DateTime.now(),
      status: DownloadStatus.packaging,
      deleteRemoteAfterDownload: true,
    );
    task.cancelToken = CancelToken();

    state = [...state, task];
    _persistToDisk();

    try {
      final FileRepository repo = await _getRepository(serverId);
      await repo.compressFiles(
        files: remotePaths,
        type: 'zip',
        dst: '/tmp',
        name: fileName,
        replace: true,
      );
      _executeDownload(task);
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      state = [...state];
      _persistToDisk();
    }

    return taskId;
  }

  void cancelDownload(String taskId) {
    final task = _findTask(taskId);
    if (task == null || task.isDone) return;
    task.cancelToken?.cancel('user cancelled');
    task.status = DownloadStatus.cancelled;
    _endLiveActivity(task, FileTransferLiveActivityStatus.cancelled);
    state = [...state];
    _persistToDisk();
  }

  Future<void> retryDownload(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return;

    task.status = DownloadStatus.pending;
    task.progress = 0.0;
    task.speed = 0.0;
    task.errorMessage = null;
    task.cancelToken = CancelToken();

    final baseDir = await _ensureServerDir(task.serverId);
    task.localPath = _resolveLocalPath(baseDir, task.fileName);

    state = [...state];
    _persistToDisk();
    _executeDownload(task);
  }

  Future<void> deleteDownload(String taskId) async {
    final task = _findTask(taskId);
    if (task == null) return;

    if (!task.isDone) {
      task.cancelToken?.cancel('deleted');
      _endLiveActivity(task, FileTransferLiveActivityStatus.cancelled);
    }

    try {
      final file = File(task.localPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    state = state.where((t) => t.id != taskId).toList();
    _persistToDisk();
  }

  Future<void> shareFile(String taskId) async {
    final task = _findTask(taskId);
    if (task == null || task.status != DownloadStatus.completed) return;

    final file = File(task.localPath);
    if (!await file.exists()) return;

    final mime = _guessMimeType(task.fileName);
    await SharePlus.instance.share(
      ShareParams(
        title: task.fileName,
        subject: task.fileName,
        files: [XFile(task.localPath, mimeType: mime)],
        fileNameOverrides: [task.fileName],
      ),
    );
  }

  void clearCompleted(int serverId) {
    final toRemove = state
        .where((t) => t.serverId == serverId && t.isDone)
        .map((t) => t.id)
        .toSet();
    if (toRemove.isEmpty) return;

    for (final t in state.where((t) => toRemove.contains(t.id))) {
      try {
        final f = File(t.localPath);
        if (f.existsSync() && t.status != DownloadStatus.completed) {
          f.deleteSync();
        }
      } catch (_) {}
    }

    state = state.where((t) => !toRemove.contains(t.id)).toList();
    _persistToDisk();
  }

  Future<void> deleteAllDownloads(int serverId) async {
    final serverTasks = state.where((t) => t.serverId == serverId).toList();
    if (serverTasks.isEmpty) return;

    for (final task in serverTasks) {
      if (!task.isDone) {
        task.cancelToken?.cancel('deleted all');
        _endLiveActivity(task, FileTransferLiveActivityStatus.cancelled);
      }
      try {
        final file = File(task.localPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    state = state.where((t) => t.serverId != serverId).toList();
    _persistToDisk();
  }

  List<DownloadTask> tasksForServer(int serverId) =>
      state.where((t) => t.serverId == serverId).toList();

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  DownloadTask? _findTask(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _executeDownload(DownloadTask task) async {
    if (task.status == DownloadStatus.packaging) {
      await _startLiveActivity(task, FileTransferLiveActivityStatus.preparing);
      try {
        final FileRepository repo = await _getRepository(task.serverId);
        bool exists = false;
        int retries = 0;
        // 轮询服务器打包状态，最多等待 5 分钟 (5s * 60)
        while (!exists && retries < 60) {
          if (task.cancelToken?.isCancelled == true) return;
          exists = await repo.checkFileExists(task.remotePath);
          if (!exists) {
            await Future.delayed(const Duration(seconds: 5));
            retries++;
          }
        }

        if (!exists) {
          throw Exception(
            ref.read(appLocalizationsProvider).download_packagingTimeoutFailed,
          );
        }

        // 打包完成，获取实际文件大小并开始下载
        task.fileSize = await repo.getFileSize(task.remotePath);
        task.status = DownloadStatus.downloading;
        task.lastReceived = 0;
        task.receivedBytes = 0;
        task.lastSpeedTime = DateTime.now();
        state = [...state];
        _updateLiveActivity(
          task,
          status: FileTransferLiveActivityStatus.running,
          force: true,
        );
      } catch (e) {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
        _endLiveActivity(task, FileTransferLiveActivityStatus.failed);
        state = [...state];
        _persistToDisk();
        return;
      }
    } else {
      task.status = DownloadStatus.downloading;
      task.lastReceived = 0;
      task.receivedBytes = 0;
      task.lastSpeedTime = DateTime.now();
      state = [...state];
      await _startLiveActivity(task, FileTransferLiveActivityStatus.running);
    }

    try {
      final client = await ref.read(dioClientProvider(task.serverId).future);
      await FileApi(client).downloadFile(
        path: task.remotePath,
        savePath: task.localPath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(task.lastSpeedTime).inMilliseconds;
          task.receivedBytes = received;
          if (total > 0 && task.fileSize <= 0) {
            task.fileSize = total;
          }

          if (elapsed >= 500) {
            final diff = received - task.lastReceived;
            task.speed = diff / (elapsed / 1000.0);
            task.lastReceived = received;
            task.lastSpeedTime = now;
          }

          task.progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
          _updateLiveActivity(task);
          state = [...state];
        },
      );

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.speed = 0.0;
      task.receivedBytes = task.fileSize;
      _endLiveActivity(task, FileTransferLiveActivityStatus.completed);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.cancelled;
        _endLiveActivity(task, FileTransferLiveActivityStatus.cancelled);
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage =
            e.message ?? ref.read(appLocalizationsProvider).download_failed;
        _endLiveActivity(task, FileTransferLiveActivityStatus.failed);
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      _endLiveActivity(task, FileTransferLiveActivityStatus.failed);
    } finally {
      // 如果是临时文件（打包产生的），下载完成后尝试删除服务器端的临时文件
      if (task.deleteRemoteAfterDownload) {
        try {
          final FileRepository repo = await _getRepository(task.serverId);
          await repo.deleteFile(
            path: task.remotePath,
            isDir: false,
            forceDelete: true,
          );
        } catch (_) {}
      }
    }

    state = [...state];
    _persistToDisk();
  }

  Future<void> _startLiveActivity(
    DownloadTask task,
    FileTransferLiveActivityStatus status,
  ) async {
    task.lastLiveActivityUpdate = DateTime.now();
    await FileTransferLiveActivityService.start(
      id: task.id,
      direction: FileTransferLiveActivityDirection.download,
      fileName: task.fileName,
      totalBytes: task.fileSize,
      transferredBytes: task.receivedBytes,
      progress: task.progress,
      speedBytesPerSecond: task.speed,
      status: status,
    );
  }

  void _updateLiveActivity(
    DownloadTask task, {
    FileTransferLiveActivityStatus status =
        FileTransferLiveActivityStatus.running,
    bool force = false,
  }) {
    final now = DateTime.now();
    if (!force &&
        now.difference(task.lastLiveActivityUpdate) <
            _liveActivityUpdateInterval) {
      return;
    }
    task.lastLiveActivityUpdate = now;

    unawaited(
      FileTransferLiveActivityService.update(
        id: task.id,
        totalBytes: task.fileSize,
        transferredBytes: task.receivedBytes,
        progress: task.progress,
        speedBytesPerSecond: task.speed,
        status: status,
      ),
    );
  }

  void _endLiveActivity(
    DownloadTask task,
    FileTransferLiveActivityStatus status,
  ) {
    unawaited(
      FileTransferLiveActivityService.end(
        id: task.id,
        totalBytes: task.fileSize,
        transferredBytes: status == FileTransferLiveActivityStatus.completed
            ? task.fileSize
            : task.receivedBytes,
        progress: status == FileTransferLiveActivityStatus.completed
            ? 1.0
            : task.progress,
        status: status,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 持久化
  // ---------------------------------------------------------------------------

  Future<File> _tasksFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return File('${downloadDir.path}/tasks.json');
  }

  Future<void> _persistToDisk() async {
    try {
      final file = await _tasksFile();
      final jsonList = state.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('DownloadManager: persist failed $e');
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _tasksFile();
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final tasks = jsonList
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();

      // 恢复后，正在下载的任务标记为失败（App 重启后连接已断）
      var hasInterruptedTask = false;
      for (final t in tasks) {
        if (t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.pending) {
          hasInterruptedTask = true;
          t.status = DownloadStatus.failed;
          t.errorMessage = ref
              .read(appLocalizationsProvider)
              .download_interrupted;
        }
      }
      if (hasInterruptedTask) {
        unawaited(FileTransferLiveActivityService.endAll());
      }

      state = tasks;
    } catch (e) {
      debugPrint('DownloadManager: load failed $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  Future<String> _ensureServerDir(int serverId) async {
    final dir = await getApplicationDocumentsDirectory();
    final serverDir = Directory('${dir.path}/downloads/$serverId');
    if (!await serverDir.exists()) {
      await serverDir.create(recursive: true);
    }
    return serverDir.path;
  }

  /// 文件名冲突时自动追加 (1), (2) 后缀
  String _resolveLocalPath(String dir, String fileName) {
    var target = File('$dir/$fileName');
    if (!target.existsSync()) return target.path;

    final dotIndex = fileName.lastIndexOf('.');
    final name = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex > 0 ? fileName.substring(dotIndex) : '';

    var counter = 1;
    while (target.existsSync()) {
      target = File('$dir/$name ($counter)$ext');
      counter++;
    }
    return target.path;
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'txt' ||
      'log' ||
      'conf' ||
      'cfg' ||
      'ini' ||
      'yaml' ||
      'yml' ||
      'json' ||
      'xml' ||
      'md' ||
      'sh' ||
      'py' ||
      'js' ||
      'css' ||
      'html' => 'text/plain',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'gz' || 'tgz' => 'application/gzip',
      'tar' => 'application/x-tar',
      'mp4' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      _ => 'application/octet-stream',
    };
  }
}
