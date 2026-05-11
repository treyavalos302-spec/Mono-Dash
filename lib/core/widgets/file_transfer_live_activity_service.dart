import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FileTransferLiveActivityDirection { upload, download }

enum FileTransferLiveActivityStatus {
  preparing,
  running,
  completed,
  failed,
  cancelled,
}

class FileTransferLiveActivityService {
  const FileTransferLiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'mono_dash/file_transfer_live_activity',
  );

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      debugPrint('FileTransferLiveActivity: isSupported failed $e');
      return false;
    }
  }

  static Future<void> start({
    required String id,
    required FileTransferLiveActivityDirection direction,
    required String fileName,
    required int totalBytes,
    int transferredBytes = 0,
    double progress = 0,
    double speedBytesPerSecond = 0,
    FileTransferLiveActivityStatus status =
        FileTransferLiveActivityStatus.running,
  }) => _invoke('start', {
    'id': id,
    'direction': direction.name,
    'fileName': fileName,
    'totalBytes': totalBytes,
    'transferredBytes': transferredBytes,
    'progress': progress,
    'speedBytesPerSecond': speedBytesPerSecond,
    'status': status.name,
  });

  static Future<void> update({
    required String id,
    required int totalBytes,
    required int transferredBytes,
    required double progress,
    required double speedBytesPerSecond,
    required FileTransferLiveActivityStatus status,
  }) => _invoke('update', {
    'id': id,
    'totalBytes': totalBytes,
    'transferredBytes': transferredBytes,
    'progress': progress,
    'speedBytesPerSecond': speedBytesPerSecond,
    'status': status.name,
  });

  static Future<void> end({
    required String id,
    required int totalBytes,
    required int transferredBytes,
    required double progress,
    required FileTransferLiveActivityStatus status,
  }) => _invoke('end', {
    'id': id,
    'totalBytes': totalBytes,
    'transferredBytes': transferredBytes,
    'progress': progress,
    'speedBytesPerSecond': 0.0,
    'status': status.name,
  });

  static Future<void> endAll() => _invoke('endAll');

  static Future<void> _invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      debugPrint('FileTransferLiveActivity: $method failed $e');
    }
  }
}
