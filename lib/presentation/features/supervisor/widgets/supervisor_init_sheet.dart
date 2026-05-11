import 'package:flutter/cupertino.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../data/dto/host_tool/supervisor_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_form_components.dart';
import 'supervisor_common_widgets.dart';

Future<void> showSupervisorInitSheet(
  BuildContext context, {
  required SupervisorToolStatus status,
  required Future<void> Function(String configPath, String serviceName)
  onSubmit,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (_) => _SupervisorInitSheet(status: status, onSubmit: onSubmit),
  );
}

class _SupervisorInitSheet extends StatefulWidget {
  const _SupervisorInitSheet({required this.status, required this.onSubmit});

  final SupervisorToolStatus status;
  final Future<void> Function(String configPath, String serviceName) onSubmit;

  @override
  State<_SupervisorInitSheet> createState() => _SupervisorInitSheetState();
}

class _SupervisorInitSheetState extends State<_SupervisorInitSheet> {
  late final TextEditingController _configPath;
  late final TextEditingController _serviceName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _configPath = TextEditingController(text: widget.status.configPath);
    _serviceName = TextEditingController(text: widget.status.serviceName);
  }

  @override
  void dispose() {
    _configPath.dispose();
    _serviceName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _configPath.text.trim();
    final service = _serviceName.text.trim();
    if (path.isEmpty || service.isEmpty) {
      showAppWarningToast(context.l10n.supervisor_configPathAndServiceRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(path, service);
      if (!mounted) return;
      Navigator.pop(context);
      showAppSuccessToast(context.l10n.supervisor_initSuccess);
    } catch (e) {
      showAppErrorToast(
        context.l10n.supervisor_initFailed,
        description: '$e',
        copyText: '$e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionSheetScaffold(
      isAdaptive: true,
      showHandle: true,
      maxHeightFactor: 0.72,
      title: context.l10n.supervisor_initTitle,
      child: Column(
        children: [
          SupervisorNoticeCard(
            icon: TablerIcons.alert_triangle,
            color: CupertinoColors.systemRed,
            text: context.l10n.supervisor_initWarning,
          ),
          const SizedBox(height: 16),
          AppFormItem(
            label: context.l10n.supervisor_primaryConfig,
            icon: TablerIcons.file_settings,
            child: AppFormTextField(
              controller: _configPath,
              placeholder: '/etc/supervisord.conf',
            ),
          ),
          const SizedBox(height: 14),
          AppFormItem(
            label: context.l10n.supervisor_serviceName,
            icon: TablerIcons.server_cog,
            child: AppFormTextField(
              controller: _serviceName,
              placeholder: 'supervisord',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const CupertinoActivityIndicator()
                  : Text(context.l10n.common_confirm),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
