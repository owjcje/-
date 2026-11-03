import 'package:flutter/material.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';

/// 编辑主任务或子任务名称，并只返回经过清理的非空名称。
class EditWorkItemTitleDialog extends StatefulWidget {
  const EditWorkItemTitleDialog({
    required this.initialTitle,
    required this.isSubtask,
    super.key,
  });

  final String initialTitle;
  final bool isSubtask;

  @override
  State<EditWorkItemTitleDialog> createState() {
    return _EditWorkItemTitleDialogState();
  }
}

class _EditWorkItemTitleDialogState extends State<EditWorkItemTitleDialog> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialTitle.length,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.isSubtask
            ? localizations.editSubtaskTitle
            : localizations.editTaskTitle,
      ),
      content: Semantics(
        identifier: widget.isSubtask
            ? 'editSubtaskDialog.titleInput' // 自动化测试用标识：编辑子任务名称输入框
            : 'editTaskDialog.titleInput', // 自动化测试用标识：编辑主任务名称输入框
        child: TextField(
          controller: _titleController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.isSubtask
                ? localizations.subtaskName
                : localizations.taskName,
          ),
          onSubmitted: (String value) => _submit(),
        ),
      ),
      actions: <Widget>[
        Semantics(
          identifier: widget.isSubtask
              ? 'editSubtaskDialog.cancelButton' // 自动化测试用标识：取消编辑子任务按钮
              : 'editTaskDialog.cancelButton', // 自动化测试用标识：取消编辑主任务按钮
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
        ),
        Semantics(
          identifier: widget.isSubtask
              ? 'editSubtaskDialog.saveButton' // 自动化测试用标识：保存子任务名称按钮
              : 'editTaskDialog.saveButton', // 自动化测试用标识：保存主任务名称按钮
          child: FilledButton(
            onPressed: _submit,
            child: Text(localizations.save),
          ),
        ),
      ],
    );
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop<String>(title);
  }
}

/// 编辑子任务备注，并允许以空文本清除既有内容。
class EditSubtaskNoteDialog extends StatefulWidget {
  const EditSubtaskNoteDialog({required this.initialNote, super.key});

  final String initialNote;

  @override
  State<EditSubtaskNoteDialog> createState() => _EditSubtaskNoteDialogState();
}

class _EditSubtaskNoteDialogState extends State<EditSubtaskNoteDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.editSubtaskNote),
      content: SizedBox(
        width: 640, // 备注编辑弹窗在桌面端提供更宽输入区域
        height: 360, // 为较长工作记录预留可见输入高度
        child: Semantics(
          identifier: 'editSubtaskNoteDialog.noteInput', // 自动化测试用标识：编辑子任务备注输入框
          child: TextField(
            controller: _noteController,
            autofocus: true,
            minLines: 10,
            maxLines: 14,
            decoration: InputDecoration(labelText: localizations.subtaskNote),
          ),
        ),
      ),
      actions: <Widget>[
        Semantics(
          identifier: 'editSubtaskNoteDialog.cancelButton', // 自动化测试用标识：取消编辑子任务备注按钮
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
        ),
        Semantics(
          identifier: 'editSubtaskNoteDialog.saveButton', // 自动化测试用标识：保存子任务备注按钮
          child: FilledButton(
            onPressed: _submit,
            child: Text(localizations.save),
          ),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop<String>(_noteController.text.trim());
  }
}

/// 编辑单条计时记录的开始与结束时间。
class EditTimeEntryDialog extends StatefulWidget {
  const EditTimeEntryDialog({required this.entry, super.key});

  final WorkTimeEntry entry;

  @override
  State<EditTimeEntryDialog> createState() => _EditTimeEntryDialogState();
}

class _EditTimeEntryDialogState extends State<EditTimeEntryDialog> {
  late DateTime _startedAt;
  late DateTime _endedAt;
  bool _isTimeRangeInvalid = false;

  @override
  void initState() {
    super.initState();
    _startedAt = widget.entry.startedAt;
    _endedAt = widget.entry.endedAt ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.editTimeEntry),
      content: _buildContent(context, localizations),
      actions: _buildActions(localizations),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return SizedBox(
      width: 420, // 计时编辑弹窗在桌面端保留双时间选择控件的舒适宽度
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTimeButton(
            context,
            label: localizations.startedAt,
            value: _startedAt,
            identifier: 'editTimeEntryDialog.startTimeButton.${widget.entry.id}', // 自动化测试用标识：计时记录开始时间选择按钮
            onPressed: _selectStartedAt,
          ),
          const SizedBox(height: 16),
          _buildTimeButton(
            context,
            label: localizations.endedAt,
            value: _endedAt,
            identifier: 'editTimeEntryDialog.endTimeButton.${widget.entry.id}', // 自动化测试用标识：计时记录结束时间选择按钮
            onPressed: _selectEndedAt,
          ),
          if (widget.entry.isRunning) ...<Widget>[
            const SizedBox(height: 12),
            Text(localizations.runningEntryEditHint),
          ],
          if (_isTimeRangeInvalid) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              localizations.invalidTimeRange,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(AppLocalizations localizations) {
    return <Widget>[
        Semantics(
          identifier: 'editTimeEntryDialog.cancelButton.${widget.entry.id}', // 自动化测试用标识：取消编辑计时记录按钮
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
        ),
        Semantics(
          identifier: 'editTimeEntryDialog.saveButton.${widget.entry.id}', // 自动化测试用标识：保存计时记录时间按钮
          child: FilledButton(
            onPressed: _submit,
            child: Text(localizations.save),
          ),
        ),
      ];
  }

  Widget _buildTimeButton(
    BuildContext context, {
    required String label,
    required DateTime value,
    required String identifier,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      identifier: identifier, // 自动化测试用标识：由调用方指定计时记录时间选择按钮
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(MaterialLocalizations.of(context).formatFullDate(value)),
            const SizedBox(width: 8),
            Text(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartedAt() async {
    final DateTime? selectedAt = await _pickDateTime(_startedAt);
    if (selectedAt == null || !mounted) {
      return;
    }
    setState(() {
      _startedAt = selectedAt;
      _isTimeRangeInvalid = false;
    });
  }

  Future<void> _selectEndedAt() async {
    final DateTime? selectedAt = await _pickDateTime(_endedAt);
    if (selectedAt == null || !mounted) {
      return;
    }
    setState(() {
      _endedAt = selectedAt;
      _isTimeRangeInvalid = false;
    });
  }

  Future<DateTime?> _pickDateTime(DateTime initialValue) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return null;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
    );
    if (time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!_endedAt.isAfter(_startedAt)) {
      setState(() {
        _isTimeRangeInvalid = true;
      });
      return;
    }
    Navigator.of(context).pop<TimeEntryEditResult>(
      TimeEntryEditResult(startedAt: _startedAt, endedAt: _endedAt),
    );
  }
}

/// 保存编辑计时记录弹窗后返回的时间范围。
class TimeEntryEditResult {
  const TimeEntryEditResult({required this.startedAt, required this.endedAt});

  final DateTime startedAt;
  final DateTime endedAt;
}

/// 删除前展示影响范围，防止误删任务及其关联计时记录。
class DeleteWorkItemDialog extends StatelessWidget {
  const DeleteWorkItemDialog({
    required this.title,
    required this.isSubtask,
    super.key,
  });

  final String title;
  final bool isSubtask;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        isSubtask ? localizations.deleteSubtask : localizations.deleteTask,
      ),
      content: Text(
        isSubtask
            ? localizations.deleteSubtaskConfirmation(title)
            : localizations.deleteTaskConfirmation(title),
      ),
      actions: <Widget>[
        Semantics(
          identifier: isSubtask
              ? 'deleteSubtaskDialog.cancelButton' // 自动化测试用标识：取消删除子任务按钮
              : 'deleteTaskDialog.cancelButton', // 自动化测试用标识：取消删除主任务按钮
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
        ),
        Semantics(
          identifier: isSubtask
              ? 'deleteSubtaskDialog.confirmButton' // 自动化测试用标识：确认删除子任务按钮
              : 'deleteTaskDialog.confirmButton', // 自动化测试用标识：确认删除主任务按钮
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations.delete),
          ),
        ),
      ],
    );
  }
}
