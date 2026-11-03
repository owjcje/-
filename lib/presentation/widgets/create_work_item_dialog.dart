import 'package:flutter/material.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';

typedef CreateWorkItemResult = ({
  String title,
  WorkItemStatus status,
});

/// 收集新主任务或子任务的名称与初始状态。
class CreateWorkItemDialog extends StatefulWidget {
  const CreateWorkItemDialog({
    required this.isSubtask,
    super.key,
  });

  final bool isSubtask;

  @override
  State<CreateWorkItemDialog> createState() {
    return _CreateWorkItemDialogState();
  }
}

class _CreateWorkItemDialogState extends State<CreateWorkItemDialog> {
  final TextEditingController _titleController = TextEditingController();
  WorkItemStatus _selectedStatus = WorkItemStatus.notStarted;

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
            ? localizations.createSubtask
            : localizations.createTask,
      ),
      content: SizedBox(
        width: 420, // 桌面端创建弹窗内容宽度
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildTitleField(localizations),
            const SizedBox(height: 18),
            _buildStatusField(localizations),
          ],
        ),
      ),
      actions: <Widget>[
        _buildCancelButton(localizations),
        _buildCreateButton(localizations),
      ],
    );
  }

  Widget _buildTitleField(AppLocalizations localizations) {
    return Semantics(
      identifier: widget.isSubtask
          ? 'createSubtaskDialog.titleInput' // 自动化测试用标识：子任务名称输入框
          : 'createTaskDialog.titleInput', // 自动化测试用标识：任务名称输入框
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
    );
  }

  Widget _buildStatusField(AppLocalizations localizations) {
    return Semantics(
      identifier: widget.isSubtask
          ? 'createSubtaskDialog.statusSelect' // 自动化测试用标识：子任务状态选择器
          : 'createTaskDialog.statusSelect', // 自动化测试用标识：任务状态选择器
      child: DropdownButtonFormField<WorkItemStatus>(
        value: _selectedStatus,
        decoration: InputDecoration(
          labelText: localizations.selectStatus,
        ),
        items: WorkItemStatus.values.map((WorkItemStatus status) {
          return DropdownMenuItem<WorkItemStatus>(
            value: status,
            child: Semantics(
              identifier: widget.isSubtask
                  ? 'createSubtaskDialog.statusOption.${status.name}' // 自动化测试用标识：子任务状态选项
                  : 'createTaskDialog.statusOption.${status.name}', // 自动化测试用标识：任务状态选项
              child: Text(localizations.workItemStatus(status)),
            ),
          );
        }).toList(growable: false),
        onChanged: (WorkItemStatus? status) {
          if (status == null) {
            return;
          }
          setState(() {
            _selectedStatus = status;
          });
        },
      ),
    );
  }

  Widget _buildCancelButton(AppLocalizations localizations) {
    return Semantics(
      identifier: widget.isSubtask
          ? 'createSubtaskDialog.cancelButton' // 自动化测试用标识：取消创建子任务按钮
          : 'createTaskDialog.cancelButton', // 自动化测试用标识：取消创建任务按钮
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(localizations.cancel),
      ),
    );
  }

  Widget _buildCreateButton(AppLocalizations localizations) {
    return Semantics(
      identifier: widget.isSubtask
          ? 'createSubtaskDialog.createButton' // 自动化测试用标识：确认创建子任务按钮
          : 'createTaskDialog.createButton', // 自动化测试用标识：确认创建任务按钮
      child: FilledButton(
        onPressed: _submit,
        child: Text(localizations.create),
      ),
    );
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop<CreateWorkItemResult>(
      (title: title, status: _selectedStatus),
    );
  }
}
