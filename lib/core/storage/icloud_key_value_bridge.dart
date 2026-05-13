import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class ICloudKeyValueBridge {
  ICloudKeyValueBridge() {
    _installHandler();
  }

  static const _channel = MethodChannel('mono_dash/icloud_kvs');
  static final _remoteChanges = StreamController<String>.broadcast();
  static bool _handlerInstalled = false;

  Stream<String> get remoteChanges => _remoteChanges.stream;

  bool get _isSupportedPlatform => Platform.isIOS || Platform.isMacOS;

  Future<void> start() async {
    if (!_isSupportedPlatform) return;
    await _channel.invokeMethod<void>('start');
  }

  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<String?> getString(String key) async {
    if (!_isSupportedPlatform) return null;
    return _channel.invokeMethod<String>('getString', {'key': key});
  }

  Future<void> setString(String key, String value) async {
    if (!_isSupportedPlatform) return;
    await _channel.invokeMethod<void>('setString', {
      'key': key,
      'value': value,
    });
  }

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'remoteValueChanged') return null;

      final arguments = call.arguments;
      final key = arguments is Map ? arguments['key'] as String? : null;
      if (key != null && key.isNotEmpty) {
        _remoteChanges.add(key);
      }
      return null;
    });
  }
}
