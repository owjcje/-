import 'package:flutter/material.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/domain/entities/work_time_export_request.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';

/// 让用户选择需要写入 Excel 的主任务。
class WorkTimeExportDialog extends StatefulWidget {
  const WorkTimeExportDialog({
    required this.tasks,
    required this.initialSelectedTaskId,
    super.key,
  });

  final List<WorkTaskSummary> tasks;
  final String? initialSelectedTaskId;

  @override
  State<WorkTimeExportDialog> createState() {
    return _WorkTimeExportDialogState();
  }
}

class _WorkTimeExportDialogState extends State<WorkTimeExportDialog> {
  late final Set<String> _selectedTaskIds;
  late DateTimeRange _selectedDateRange;

  @override
  void initState() {
    super.initState();
    final String? taskId = widget.initialSelectedTaskId;
    _selectedTaskIds = taskId == null ? <String>{} : <String>{taskId};
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    _selectedDateRange = DateTimeRange(start: today, end: today);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(localizations.exportWorkTime),
      content: SizedBox(
        width: 460, // 导出任务选择列表宽度
        height: 420, // 包含日期范围选择的导出弹窗高度
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(localizations.exportDateRange),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'workTimeExportDialog.dateRangeButton', // 自动化测试用标识：导出日期范围选择按钮
              child: OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_formatDateRange(context)),
              ),
            ),
            const SizedBox(height: 16),
            Text(localizations.exportTaskSelectionHint),
            const SizedBox(height: 8),
            Semantics(
              identifier: 'workTimeExportDialog.selectAllButton', // 自动化测试用标识：导出任务全选按钮
              child: TextButton(
                onPressed: _toggleSelectAll,
                child: Text(
                  _selectedTaskIds.length == widget.tasks.length
                      ? localizations.clearSelection
                      : localizations.selectAll,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.tasks.length,
                itemBuilder: (BuildContext context, int index) {
                  final WorkTaskSummary task = widget.tasks[index];
                  final bool isSelected = _selectedTaskIds.contains(task.id);
                  return Semantics(
                    identifier: 'workTimeExportDialog.taskOption.${task.id}', // 自动化测试用标识：指定主任务导出选项
                    child: CheckboxListTile(
                      value: isSelected,
                      title: Text(task.title),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        _setTaskSelected(task.id, value ?? false);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        Semantics(
          identifier: 'workTimeExportDialog.cancelButton', // 自动化测试用标识：取消导出按钮
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
        ),
        Semantics(
          identifier: 'workTimeExportDialog.confirmButton', // 自动化测试用标识：确认导出按钮
          child: FilledButton(
            onPressed: _selectedTaskIds.isEmpty ? null : _submit,
            child: Text(localizations.export),
          ),
        ),
      ],
    );
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedTaskIds.length == widget.tasks.length) {
        _selectedTaskIds.clear();
        return;
      }
      _selectedTaskIds.addAll(
        widget.tasks.map((WorkTaskSummary task) => task.id),
      );
    });
  }

  void _setTaskSelected(String taskId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedTaskIds.add(taskId);
        return;
      }
      _selectedTaskIds.remove(taskId);
    });
  }

  void _submit() {
    final List<String> selectedTaskIds = widget.tasks
        .where((WorkTaskSummary task) => _selectedTaskIds.contains(task.id))
        .map((WorkTaskSummary task) => task.id)
        .toList(growable: false);
    Navigator.of(context).pop<WorkTimeExportRequest>(
      WorkTimeExportRequest(
        taskIds: selectedTaskIds,
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTimeRange? selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: AppLocalizations.of(context).exportDateRange,
    );
    if (selectedRange == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDateRange = selectedRange;
    });
  }

  String _formatDateRange(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final String startDate = localizations.formatShortDate(_selectedDateRange.start);
    final String endDate = localizations.formatShortDate(_selectedDateRange.end);
    return '$startDate - $endDate';
  }
}
