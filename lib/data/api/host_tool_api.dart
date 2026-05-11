import 'package:dio/dio.dart';

import '../../core/network/api_response_parser.dart';
import '../../core/network/dio_client.dart';
import '../dto/host_tool/supervisor_dto.dart';

/// 主机工具 API（对应 1Panel `/hosts/tool` 相关接口）。
class HostToolApi {
  HostToolApi(this._client);

  final DioClient _client;

  Future<SupervisorToolStatus> getSupervisorStatus() async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool',
      data: const {'type': 'supervisord', 'operate': 'status'},
    );
    return ApiResponseParser.object(resp, SupervisorToolStatus.fromJson);
  }

  Future<void> operateSupervisor(String operate) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/operate',
      data: {'type': 'supervisord', 'operate': operate},
    );
  }

  Future<void> initSupervisor({
    required String configPath,
    required String serviceName,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/init',
      data: {
        'type': 'supervisord',
        'configPath': configPath,
        'serviceName': serviceName,
      },
    );
  }

  Future<String> operateSupervisorConfig({
    required String operate,
    String content = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/config',
      data: {
        'type': 'supervisord',
        'operate': operate,
        if (content.isNotEmpty || operate == 'set') 'content': content,
      },
    );
    final data = ApiResponseParser.map(resp);
    return data['content'] as String? ?? '';
  }

  Future<List<SupervisorProcessConfig>> getSupervisorProcesses() async {
    final resp = await _client.get<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process',
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return ApiResponseParser.list(resp, SupervisorProcessConfig.fromJson);
  }

  Future<void> submitSupervisorProcess(
    SupervisorProcessConfig config, {
    required String operate,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process',
      data: config.toSubmitJson(operate),
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<void> operateSupervisorProcess({
    required String name,
    required String operate,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process',
      data: {'name': name, 'operate': operate},
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<String> operateSupervisorProcessFile({
    required String name,
    required String file,
    required String operate,
    String content = '',
  }) async {
    final resp = await _client.post<Map<String, dynamic>>(
      '/api/v2/hosts/tool/supervisor/process/file',
      data: {
        'name': name,
        'file': file,
        'operate': operate,
        if (content.isNotEmpty || operate == 'update') 'content': content,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final data = resp.data?['data'];
    return data is String ? data : '';
  }
}
