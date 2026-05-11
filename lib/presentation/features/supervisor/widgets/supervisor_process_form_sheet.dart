import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/localization/l10n_x.dart';
import '../../../../data/dto/host_tool/supervisor_dto.dart';
import '../../../common/app_toast.dart';
import '../../../common/components/action_sheet_launcher.dart';
import '../../../common/components/action_sheet_scaffold.dart';
import '../../../common/components/app_form_components.dart';
import '../../../common/components/file_browser_picker_sheet.dart';
import 'supervisor_common_widgets.dart';

Future<void> showSupervisorProcessFormSheet(
  BuildContext context, {
  SupervisorProcessConfig? initial,
  required Future<void> Function(SupervisorProcessConfig config, String operate)
  onSubmit,
}) {
  return showActionSheet<void>(
    context: context,
    builder: (_) =>
        _SupervisorProcessFormSheet(initial: initial, onSubmit: onSubmit),
  );
}

class _SupervisorProcessFormSheet extends StatefulWidget {
  const _SupervisorProcessFormSheet({this.initial, required this.onSubmit});

  final SupervisorProcessConfig? initial;
  final Future<void> Function(SupervisorProcessConfig config, String operate)
  onSubmit;

  @override
  State<_SupervisorProcessFormSheet> createState() =>
      _SupervisorProcessFormSheetState();
}

class _SupervisorProcessFormSheetState
    extends State<_SupervisorProcessFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _user;
  late final TextEditingController _dir;
  late final TextEditingController _command;
  late final TextEditingController _numprocs;
  late final TextEditingController _environment;
  bool _autoRestart = true;
  bool _autoStart = true;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _user = TextEditingController(text: initial?.user ?? 'root');
    _dir = TextEditingController(text: initial?.dir ?? '');
    _command = TextEditingController(text: initial?.command ?? '');
    _numprocs = TextEditingController(text: initial?.numprocs ?? '1');
    _environment = TextEditingController(text: initial?.environment ?? '');
    _autoRestart = (initial?.autoRestart ?? 'true') == 'true';
    _autoStart = (initial?.autoStart ?? 'true') == 'true';
  }

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _dir.dispose();
    _command.dispose();
    _numprocs.dispose();
    _environment.dispose();
    super.dispose();
  }

  Future<void> _pickDir() async {
    final result = await FileBrowserPickerSheet.show(
      context,
      initialPath: _dir.text.trim().isEmpty ? '/' : _dir.text.trim(),
      title: context.l10n.supervisor_chooseWorkDir,
      selectionMode: FilePickerSelectionMode.directories,
    );
    if (result != null) _dir.text = result.path;
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final user = _user.text.trim();
    final dir = _dir.text.trim();
    final command = _command.text.trim();
    final numprocs = int.tryParse(_numprocs.text.trim());
    if (name.isEmpty || user.isEmpty || dir.isEmpty || command.isEmpty) {
      showAppWarningToast(context.l10n.supervisor_requiredFields);
      return;
    }
    final validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$');
    if (!validName.hasMatch(name)) {
      showAppWarningToast(context.l10n.supervisor_nameRule);
      return;
    }
    if (numprocs == null || numprocs < 1 || numprocs > 9999) {
      showAppWarningToast(context.l10n.supervisor_numprocsRule);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        SupervisorProcessConfig(
          name: name,
          command: command,
          dir: dir,
          user: user,
          numprocs: '$numprocs',
          autoRestart: _autoRestart ? 'true' : 'false',
          autoStart: _autoStart ? 'true' : 'false',
          environment: _environment.text.trim(),
          status: const [],
        ),
        _isEdit ? 'update' : 'create',
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSuccessToast(
        _isEdit
            ? context.l10n.supervisor_updateSuccess
            : context.l10n.supervisor_createSuccess,
      );
    } catch (e) {
      showAppErrorToast(
        context.l10n.supervisor_saveFailed,
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
      maxHeightFactor: 0.88,
      title: _isEdit
          ? context.l10n.supervisor_editProcess
          : context.l10n.supervisor_createProcess,
      child: Column(
        children: [
          AppFormItem(
            label: context.l10n.supervisor_name,
            icon: TablerIcons.tag,
            child: AppFormTextField(
              controller: _name,
              placeholder: 'my-worker',
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          const SizedBox(height: 14),
          AppFormItem(
            label: context.l10n.supervisor_user,
            icon: TablerIcons.user,
            child: AppFormTextField(controller: _user, placeholder: 'root'),
          ),
          const SizedBox(height: 14),
          AppFormItem(
            label: context.l10n.supervisor_workDir,
            icon: TablerIcons.folder,
            child: AppFormTextField(
              controller: _dir,
              placeholder: '/www/wwwroot/app',
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 10),
                minimumSize: Size.zero,
                onPressed: _pickDir,
                child: Icon(
                  TablerIcons.folder_open,
                  size: 20,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppFormItem(
            label: context.l10n.supervisor_command,
            icon: TablerIcons.terminal_2,
            child: AppFormTextField(
              controller: _command,
              placeholder: 'php artisan queue:work',
            ),
          ),
          const SizedBox(height: 14),
          AppFormItem(
            label: context.l10n.supervisor_numprocs,
            icon: TablerIcons.hash,
            child: AppFormTextField(
              controller: _numprocs,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(height: 14),
          AppFormItem(
            label: context.l10n.supervisor_environment,
            icon: TablerIcons.braces,
            child: AppFormTextField(
              controller: _environment,
              placeholder: 'KEY="value",OTHER="value"',
            ),
          ),
          const SizedBox(height: 14),
          SupervisorSwitchTile(
            title: context.l10n.supervisor_autoRestart,
            subtitle: context.l10n.supervisor_autoRestartSubtitle,
            value: _autoRestart,
            onChanged: (v) => setState(() => _autoRestart = v),
          ),
          const SizedBox(height: 10),
          SupervisorSwitchTile(
            title: context.l10n.supervisor_autoStart,
            subtitle: context.l10n.supervisor_autoStartSubtitle,
            value: _autoStart,
            onChanged: (v) => setState(() => _autoStart = v),
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
