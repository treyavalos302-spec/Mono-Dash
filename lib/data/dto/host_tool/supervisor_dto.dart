class SupervisorToolStatus {
  const SupervisorToolStatus({
    required this.isExist,
    required this.version,
    required this.ctlExist,
    required this.status,
    required this.serviceName,
    required this.configPath,
    required this.init,
    this.includeDir = '',
    this.logPath = '',
    this.msg = '',
  });

  final bool isExist;
  final String version;
  final bool ctlExist;
  final String status;
  final String serviceName;
  final String configPath;
  final bool init;
  final String includeDir;
  final String logPath;
  final String msg;

  bool get isReady => isExist && ctlExist && !init;
  bool get isRunning => status.toLowerCase() == 'running';

  factory SupervisorToolStatus.empty() => const SupervisorToolStatus(
    isExist: false,
    version: '',
    ctlExist: false,
    status: 'stopped',
    serviceName: '',
    configPath: '',
    init: true,
  );

  factory SupervisorToolStatus.fromJson(Map<String, dynamic> json) {
    final config = json['config'];
    final source = config is Map<String, dynamic> ? config : json;
    return SupervisorToolStatus(
      isExist: source['isExist'] as bool? ?? false,
      version: source['version'] as String? ?? '',
      ctlExist: source['ctlExist'] as bool? ?? false,
      status: source['status'] as String? ?? 'stopped',
      serviceName: source['serviceName'] as String? ?? '',
      configPath: source['configPath'] as String? ?? '',
      init: source['init'] as bool? ?? true,
      includeDir: source['includeDir'] as String? ?? '',
      logPath: source['logPath'] as String? ?? '',
      msg: source['msg'] as String? ?? '',
    );
  }
}

class SupervisorProcessConfig {
  const SupervisorProcessConfig({
    required this.name,
    required this.command,
    required this.dir,
    required this.user,
    required this.numprocs,
    required this.autoRestart,
    required this.autoStart,
    required this.environment,
    required this.status,
    this.msg = '',
    this.hasLoad = true,
  });

  final String name;
  final String command;
  final String dir;
  final String user;
  final String numprocs;
  final String autoRestart;
  final String autoStart;
  final String environment;
  final List<SupervisorProcessStatus> status;
  final String msg;
  final bool hasLoad;

  SupervisorProcessConfig copyWith({
    List<SupervisorProcessStatus>? status,
    bool? hasLoad,
  }) {
    return SupervisorProcessConfig(
      name: name,
      command: command,
      dir: dir,
      user: user,
      numprocs: numprocs,
      autoRestart: autoRestart,
      autoStart: autoStart,
      environment: environment,
      status: status ?? this.status,
      msg: msg,
      hasLoad: hasLoad ?? this.hasLoad,
    );
  }

  factory SupervisorProcessConfig.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as List?;
    final statuses =
        rawStatus
            ?.whereType<Map<String, dynamic>>()
            .map(SupervisorProcessStatus.fromJson)
            .toList(growable: false) ??
        const <SupervisorProcessStatus>[];
    return SupervisorProcessConfig(
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
      dir: json['dir'] as String? ?? '',
      user: json['user'] as String? ?? '',
      numprocs: json['numprocs']?.toString() ?? '',
      autoRestart: json['autoRestart']?.toString() ?? 'true',
      autoStart: json['autoStart']?.toString() ?? 'true',
      environment: json['environment'] as String? ?? '',
      status: statuses,
      msg: json['msg'] as String? ?? '',
      hasLoad: statuses.isNotEmpty,
    );
  }

  Map<String, dynamic> toSubmitJson(String operate) => {
    'operate': operate,
    'name': name,
    'command': command,
    'dir': dir,
    'user': user,
    'numprocs': numprocs,
    'autoRestart': autoRestart,
    'autoStart': autoStart,
    'environment': environment,
  };
}

class SupervisorProcessStatus {
  const SupervisorProcessStatus({
    required this.name,
    required this.status,
    required this.pid,
    required this.uptime,
    required this.msg,
  });

  final String name;
  final String status;
  final String pid;
  final String uptime;
  final String msg;

  factory SupervisorProcessStatus.fromJson(Map<String, dynamic> json) {
    return SupervisorProcessStatus(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pid: (json['PID'] ?? json['pid'] ?? '').toString(),
      uptime: json['uptime'] as String? ?? '',
      msg: json['msg'] as String? ?? '',
    );
  }
}

enum SupervisorGroupState { starting, running, warning, stopped }

SupervisorGroupState supervisorGroupState(
  List<SupervisorProcessStatus> statuses,
) {
  if (statuses.isEmpty) return SupervisorGroupState.stopped;
  final counts = <String, int>{};
  for (final item in statuses) {
    counts[item.status] = (counts[item.status] ?? 0) + 1;
  }
  if ((counts['STARTING'] ?? 0) > 0) return SupervisorGroupState.starting;
  if ((counts['RUNNING'] ?? 0) == statuses.length) {
    return SupervisorGroupState.running;
  }
  if ((counts['RUNNING'] ?? 0) > 0) return SupervisorGroupState.warning;
  return SupervisorGroupState.stopped;
}
