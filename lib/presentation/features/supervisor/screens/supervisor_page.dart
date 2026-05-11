import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api/file_api.dart';
import '../../../../data/api/host_tool_api.dart';
import '../../../../data/dto/host_tool/supervisor_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_action_components.dart';
import '../../../common/components/app_code_editor.dart';
import '../../../common/components/app_confirm_sheet.dart';
import '../../../common/components/app_empty_state.dart';
import '../../../common/components/frosted_overlay_menu.dart';
import '../../../common/components/frosted_scaffold.dart';
import '../../../common/components/skeleton_item.dart';
import '../../files/screens/files_page.dart';
import '../../process/widgets/process_detail_sheet.dart';
import '../../server_detail/providers/active_server_provider.dart';
import '../widgets/supervisor_common_widgets.dart';
import '../widgets/supervisor_init_sheet.dart';
import '../widgets/supervisor_log_sheet.dart';
import '../widgets/supervisor_process_form_sheet.dart';

class SupervisorPage extends StatelessWidget {
  const SupervisorPage({
    super.key,
    required this.serverId,
    required this.onOpenFilesPath,
  });

  final int serverId;
  final ValueChanged<String> onOpenFilesPath;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [activeServerIdProvider.overrideWithValue(serverId)],
      child: _SupervisorContent(onOpenFilesPath: onOpenFilesPath),
    );
  }
}

class _SupervisorContent extends ConsumerStatefulWidget {
  const _SupervisorContent({required this.onOpenFilesPath});

  final ValueChanged<String> onOpenFilesPath;

  @override
  ConsumerState<_SupervisorContent> createState() => _SupervisorContentState();
}

class _SupervisorContentState extends ConsumerState<_SupervisorContent> {
  SupervisorToolStatus _status = SupervisorToolStatus.empty();
  List<SupervisorProcessConfig> _processes = const [];
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<HostToolApi> _api() async {
    final serverId = ref.read(activeServerIdProvider);
    return HostToolApi(await ref.read(dioClientProvider(serverId).future));
  }

  Future<FileApi> _fileApi() async {
    final serverId = ref.read(activeServerIdProvider);
    return FileApi(await ref.read(dioClientProvider(serverId).future));
  }

  Future<void> _loadAll() async {
    _statusTimer?.cancel();
    try {
      final api = await _api();
      final status = await api.getSupervisorStatus();
      var processes = const <SupervisorProcessConfig>[];
      if (status.isReady) {
        processes = await api.getSupervisorProcesses();
        processes = _markLoadState(processes);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _processes = processes;
        _error = null;
        _loading = false;
      });
      if (status.isRunning && processes.any((e) => !e.hasLoad)) {
        _scheduleStatusPoll(const Duration(seconds: 1));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<SupervisorProcessConfig> _markLoadState(
    List<SupervisorProcessConfig> items,
  ) {
    return items
        .map((item) => item.copyWith(hasLoad: item.status.isNotEmpty))
        .toList(growable: false);
  }

  void _scheduleStatusPoll(Duration delay) {
    _statusTimer?.cancel();
    _statusTimer = Timer(delay, _pollProcessStatus);
  }

  Future<void> _pollProcessStatus() async {
    if (!_status.isRunning || _processes.isEmpty) return;
    try {
      final latest = await (await _api()).getSupervisorProcesses();
      final byName = {for (final item in latest) item.name: item};
      var needMore = false;
      final merged = _processes
          .map((item) {
            final next = byName[item.name];
            if (next == null || next.status.isEmpty) {
              needMore = true;
              return item;
            }
            return item.copyWith(status: next.status, hasLoad: true);
          })
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _processes = merged);
      if (needMore && _status.isRunning) {
        _scheduleStatusPoll(const Duration(seconds: 2));
      }
    } catch (_) {
      if (_status.isRunning) _scheduleStatusPoll(const Duration(seconds: 3));
    }
  }

  Future<void> _refreshProcesses() async {
    _statusTimer?.cancel();
    try {
      final api = await _api();
      final processes = _markLoadState(await api.getSupervisorProcesses());
      if (!mounted) return;
      setState(() => _processes = processes);
      if (_status.isRunning && processes.any((e) => !e.hasLoad)) {
        _scheduleStatusPoll(const Duration(seconds: 1));
      }
    } catch (e) {
      showAppErrorToast(
        context.l10n.supervisor_refreshFailed,
        description: '$e',
      );
    }
  }

  Future<void> _operateService(String operate) async {
    final label = supervisorOperateLabel(context, operate);
    final successText = context.l10n.supervisor_operationSuccess;
    final confirmed = await _confirm(
      title: label,
      content: context.l10n.supervisor_serviceOperateConfirm(label),
      color: supervisorOperateColor(operate),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      await (await _api()).operateSupervisor(operate);
      showAppSuccessToast(successText);
      await _loadAll();
    });
  }

  Future<void> _operateProcess(
    SupervisorProcessConfig process,
    String operate,
  ) async {
    final label = supervisorOperateLabel(context, operate);
    final successText = context.l10n.supervisor_operationSuccess;
    final confirmed = await _confirm(
      title: label,
      content: context.l10n.supervisor_processOperateConfirm(
        label,
        process.name,
      ),
      color: supervisorOperateColor(operate),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      await (await _api()).operateSupervisorProcess(
        name: process.name,
        operate: operate,
      );
      showAppSuccessToast(successText);
      await _refreshProcesses();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    final failureText = context.l10n.supervisor_operationFailed;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      showAppErrorToast(failureText, description: '$e', copyText: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String content,
    required Color color,
  }) {
    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (_) => AppConfirmSheet(
        title: title,
        content: content,
        confirmText: title,
        confirmColor: color,
      ),
    );
  }

  void _openCreate() {
    if (!_status.isReady) {
      showAppWarningToast(context.l10n.supervisor_notReady);
      return;
    }
    showSupervisorProcessFormSheet(
      context,
      onSubmit: (config, operate) async {
        await (await _api()).submitSupervisorProcess(config, operate: operate);
        await _refreshProcesses();
      },
    );
  }

  void _openEdit(SupervisorProcessConfig process) {
    showSupervisorProcessFormSheet(
      context,
      initial: process,
      onSubmit: (config, operate) async {
        await (await _api()).submitSupervisorProcess(config, operate: operate);
        await _refreshProcesses();
      },
    );
  }

  void _openSource(SupervisorProcessConfig process) {
    showAppCodeEditorSheet(
      context,
      title: '${process.name}.ini',
      subtitle: context.l10n.supervisor_processConfigSubtitle,
      language: 'ini',
      onLoad: () async {
        return (await _api()).operateSupervisorProcessFile(
          name: process.name,
          file: 'config',
          operate: 'get',
        );
      },
      onSave: (content) async {
        final successText = context.l10n.common_saved;
        await (await _api()).operateSupervisorProcessFile(
          name: process.name,
          file: 'config',
          operate: 'update',
          content: content,
        );
        showAppSuccessToast(successText);
        await _refreshProcesses();
        return true;
      },
    );
  }

  void _openConfigSource() {
    showAppCodeEditorSheet(
      context,
      title: context.l10n.supervisor_mainConfig,
      subtitle: _status.configPath,
      language: 'ini',
      onLoad: () async {
        return (await _api()).operateSupervisorConfig(operate: 'get');
      },
      onSave: (content) async {
        final successText = context.l10n.common_saved;
        await (await _api()).operateSupervisorConfig(
          operate: 'set',
          content: content,
        );
        showAppSuccessToast(successText);
        await _loadAll();
        return true;
      },
    );
  }

  void _openLog(SupervisorProcessConfig process, String file) {
    final logName = file == 'err.log'
        ? context.l10n.supervisor_errorLog
        : context.l10n.supervisor_runLog;
    showSupervisorLogSheet(
      context,
      title: '${process.name} · $logName',
      processName: process.name,
      file: file,
      fileApiLoader: _fileApi,
      hostToolApiLoader: _api,
    );
  }

  void _openMainLog() {
    showSupervisorLogSheet(
      context,
      title: context.l10n.supervisor_mainLog,
      processName: 'supervisor',
      type: 'supervisord',
      fileApiLoader: _fileApi,
      hostToolApiLoader: _api,
    );
  }

  void _openInitSheet() {
    showSupervisorInitSheet(
      context,
      status: _status,
      onSubmit: (configPath, serviceName) async {
        await (await _api()).initSupervisor(
          configPath: configPath,
          serviceName: serviceName,
        );
        await _loadAll();
      },
    );
  }

  void _openSettings() {
    showActionSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetScaffold(
        isAdaptive: true,
        showHandle: true,
        maxHeightFactor: 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'SUPERVISOR',
              icon: TablerIcons.settings,
            ),
            AppActionGroup(
              children: [
                AppActionRow(
                  icon: TablerIcons.file_code,
                  iconColor: CupertinoColors.activeBlue,
                  title: context.l10n.supervisor_configSource,
                  subtitle: Text(
                    _status.configPath.isEmpty
                        ? context.l10n.supervisor_configSourceSubtitle
                        : _status.configPath,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openConfigSource();
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.logs,
                  iconColor: CupertinoColors.systemBrown,
                  title: context.l10n.supervisor_mainLog,
                  subtitle: Text(context.l10n.supervisor_mainLogSubtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openMainLog();
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.tool,
                  iconColor: CupertinoColors.systemOrange,
                  title: context.l10n.supervisor_baseInit,
                  subtitle: Text(context.l10n.supervisor_baseInitSubtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openInitSheet();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openDirectory(String path) {
    final targetPath = path.trim();
    if (targetPath.isEmpty) return;
    final serverId = ref.read(activeServerIdProvider);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [activeServerIdProvider.overrideWithValue(serverId)],
          child: StandaloneFilesPage(initialPath: targetPath),
        ),
      ),
    );
  }

  void _openActionSheet(SupervisorProcessConfig process) {
    final groupState = supervisorGroupState(process.status);
    showActionSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetScaffold(
        isAdaptive: true,
        showHandle: true,
        maxHeightFactor: 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: process.name, icon: TablerIcons.cpu),
            AppActionGroup(
              children: [
                AppActionRow(
                  icon: TablerIcons.player_play,
                  iconColor: CupertinoColors.systemGreen,
                  title: context.l10n.supervisor_start,
                  subtitle: Text(context.l10n.supervisor_processStartSubtitle),
                  enabled: groupState != SupervisorGroupState.running,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _operateProcess(process, 'start');
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.player_stop,
                  iconColor: CupertinoColors.systemRed,
                  title: context.l10n.supervisor_stop,
                  subtitle: Text(context.l10n.supervisor_processStopSubtitle),
                  enabled:
                      groupState == SupervisorGroupState.running ||
                      groupState == SupervisorGroupState.warning,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _operateProcess(process, 'stop');
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.refresh,
                  iconColor: CupertinoColors.systemOrange,
                  title: context.l10n.supervisor_restart,
                  subtitle: Text(
                    context.l10n.supervisor_processRestartSubtitle,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _operateProcess(process, 'restart');
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: context.l10n.supervisor_configAndLogs,
              icon: TablerIcons.tools,
            ),
            AppActionGroup(
              children: [
                AppActionRow(
                  icon: TablerIcons.edit,
                  iconColor: CupertinoColors.activeBlue,
                  title: context.l10n.common_edit,
                  subtitle: Text(context.l10n.supervisor_editSubtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openEdit(process);
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.file_code,
                  iconColor: CupertinoColors.systemTeal,
                  title: context.l10n.supervisor_sourceFile,
                  subtitle: Text(context.l10n.supervisor_sourceFileSubtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openSource(process);
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.logs,
                  iconColor: CupertinoColors.systemBrown,
                  title: context.l10n.supervisor_runLog,
                  subtitle: Text(context.l10n.supervisor_runLogSubtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openLog(process, 'out.log');
                  },
                ),
                AppActionRow(
                  icon: TablerIcons.alert_triangle,
                  iconColor: CupertinoColors.systemOrange,
                  title: context.l10n.supervisor_errorLog,
                  subtitle: Text(context.l10n.supervisor_errorLogSubtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openLog(process, 'err.log');
                  },
                ),
                if (process.dir.trim().isNotEmpty)
                  AppActionRow(
                    icon: TablerIcons.folder_open,
                    iconColor: CupertinoColors.systemOrange,
                    title: context.l10n.supervisor_workDir,
                    subtitle: Text(process.dir),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openDirectory(process.dir);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: context.l10n.supervisor_dangerZone,
              icon: TablerIcons.alert_triangle,
            ),
            AppActionGroup(
              children: [
                AppActionRow(
                  icon: TablerIcons.trash,
                  iconColor: CupertinoColors.destructiveRed,
                  title: context.l10n.common_delete,
                  subtitle: Text(context.l10n.supervisor_deleteSubtitle),
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _operateProcess(process, 'delete');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      title: context.l10n.supervisor_title,
      trailingBuilder: (isDark, isOverlapping) => FrostedOverlayMenuButton(
        label: context.l10n.common_menu,
        isDark: isDark,
        isOverlapping: isOverlapping,
        items: [
          FrostedMenuItem(
            text: context.l10n.common_create,
            icon: TablerIcons.plus,
            iconColor: CupertinoColors.systemGreen,
            action: _openCreate,
          ),
          if (_status.isExist && _status.ctlExist && !_status.init)
            FrostedMenuItem(
              text: _status.isRunning
                  ? context.l10n.supervisor_serviceStop
                  : context.l10n.supervisor_serviceStart,
              icon: _status.isRunning
                  ? TablerIcons.player_stop
                  : TablerIcons.player_play,
              iconColor: _status.isRunning
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemGreen,
              action: () =>
                  _operateService(_status.isRunning ? 'stop' : 'start'),
            ),
          if (_status.isExist && _status.ctlExist && !_status.init)
            FrostedMenuItem(
              text: context.l10n.supervisor_serviceRestart,
              icon: TablerIcons.refresh,
              iconColor: CupertinoColors.systemOrange,
              action: () => _operateService('restart'),
            ),
          FrostedMenuItem(
            text: _status.init
                ? context.l10n.supervisor_initSupervisor
                : context.l10n.supervisor_settings,
            icon: _status.init ? TablerIcons.tool : TablerIcons.settings,
            iconColor: _status.init
                ? CupertinoColors.systemOrange
                : CupertinoColors.systemGrey,
            action: _status.init ? _openInitSheet : _openSettings,
          ),
          FrostedMenuItem(
            text: context.l10n.common_refresh,
            icon: TablerIcons.refresh,
            action: _loadAll,
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _loadAll),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  FrostedScaffold.contentTopPadding(context) + 12,
                  16,
                  132,
                ),
                sliver: _buildBodySliver(),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: AppColors.background(context).withValues(alpha: 0.35),
                child: const Center(child: CupertinoActivityIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBodySliver() {
    if (_loading) {
      return SliverList.list(
        children: [
          for (var i = 0; i < 5; i++) ...[
            const SkeletonItem(width: double.infinity, height: 154),
            const SizedBox(height: 10),
          ],
        ],
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: AppEmptyState(
            icon: TablerIcons.alert_triangle,
            title: context.l10n.common_loadingFailed,
            subtitle: '$_error',
            actionLabel: context.l10n.common_retry,
            onAction: _loadAll,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          ),
        ),
      );
    }

    if (!_status.isExist) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: AppEmptyState(
            icon: TablerIcons.tool,
            title: context.l10n.supervisor_notInstalledTitle,
            subtitle: context.l10n.supervisor_notInstalledSubtitle,
            useCardStyle: false,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          ),
        ),
      );
    }
    if (!_status.ctlExist) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: AppEmptyState(
            icon: TablerIcons.terminal_2,
            title: context.l10n.supervisor_ctlMissingTitle,
            subtitle: context.l10n.supervisor_ctlMissingSubtitle,
            useCardStyle: false,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          ),
        ),
      );
    }
    if (_status.init) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: AppEmptyState(
            icon: TablerIcons.settings_2,
            title: context.l10n.supervisor_needInitTitle,
            subtitle: context.l10n.supervisor_needInitSubtitle,
            actionLabel: context.l10n.supervisor_initSupervisor,
            onAction: _openInitSheet,
            useCardStyle: false,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          ),
        ),
      );
    }
    if (_processes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: AppEmptyState(
            icon: TablerIcons.list_details,
            title: context.l10n.supervisor_emptyTitle,
            subtitle: context.l10n.supervisor_emptySubtitle,
            actionLabel: context.l10n.common_create,
            onAction: _openCreate,
            useCardStyle: false,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          ),
        ),
      );
    }

    final children = <Widget>[
      if (_status.isReady && !_status.isRunning) ...[
        SupervisorNoticeCard(
          icon: TablerIcons.alert_triangle,
          color: CupertinoColors.systemOrange,
          text: context.l10n.supervisor_serviceStoppedWarn,
        ),
        const SizedBox(height: 14),
      ],
    ];
    children.addAll([
      for (final process in _processes) ...[
        SupervisorProcessCard(
          process: process,
          onTap: () => _openActionSheet(process),
          onPrimaryOperate: () {
            final state = supervisorGroupState(process.status);
            final operate = state == SupervisorGroupState.running
                ? 'stop'
                : state == SupervisorGroupState.warning
                ? 'restart'
                : 'start';
            _operateProcess(process, operate);
          },
          onDirectoryTap: _openDirectory,
          onPidTap: (pid, status) => showProcessDetailSheet(
            context,
            pid: pid,
            ref: ref,
            summary: {
              'name': status.name,
              'status': status.status.toLowerCase(),
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    ]);

    return SliverList.list(children: children);
  }
}
