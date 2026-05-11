import 'package:dio/dio.dart';

enum DownloadStatus {
  pending,
  packaging,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.serverId,
    required this.remotePath,
    required this.fileName,
    required this.localPath,
    required this.fileSize,
    required this.createdAt,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speed = 0.0,
    this.errorMessage,
    this.deleteRemoteAfterDownload = false,
  });

  final String id;
  final int serverId;
  final String remotePath;
  final String fileName;
  String localPath;
  int fileSize;
  final DateTime createdAt;
  final bool deleteRemoteAfterDownload;

  DownloadStatus status;
  double progress; // 0.0 - 1.0
  double speed; // 字节/秒
  String? errorMessage;

  // 运行时字段，不持久化
  CancelToken? cancelToken;
  int lastReceived = 0;
  int receivedBytes = 0;
  DateTime lastSpeedTime = DateTime.now();
  DateTime lastLiveActivityUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isDone =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.cancelled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverId': serverId,
    'remotePath': remotePath,
    'fileName': fileName,
    'localPath': localPath,
    'fileSize': fileSize,
    'status': status.name,
    'progress': progress,
    'createdAt': createdAt.toIso8601String(),
    'errorMessage': errorMessage,
    'deleteRemoteAfterDownload': deleteRemoteAfterDownload,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'] as String,
    serverId: json['serverId'] as int,
    remotePath: json['remotePath'] as String,
    fileName: json['fileName'] as String,
    localPath: json['localPath'] as String,
    fileSize: json['fileSize'] as int,
    status: DownloadStatus.values.byName(json['status'] as String),
    progress: (json['progress'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    errorMessage: json['errorMessage'] as String?,
    deleteRemoteAfterDownload:
        json['deleteRemoteAfterDownload'] as bool? ?? false,
  );
}
