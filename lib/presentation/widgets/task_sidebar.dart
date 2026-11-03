import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/application/task_list_state.dart';
import 'package:work_time_tracker/application/time_tracker_providers.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';
import 'package:work_time_tracker/core/utils/time_formatters.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';
import 'package:work_time_tracker/presentation/widgets/design/app_status_filter_bar.dart';

/// 主任务导航区，提供筛选、搜索、创建和拖动排序入口。
class TaskSidebar extends StatelessWidget {
  const TaskSidebar({
    required this.state,
    required this.isCompact,
    required this.onTaskSelected,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onCreateTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onReorderTasks,
    super.key,
  });

  final TaskListState state;
  final bool isCompact;
  final ValueChanged<String> onTaskSelected;
  final ValueChanged<WorkStatusFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreateTask;
  final ValueChanged<WorkTaskSummary> onEditTask;
  final ValueChanged<WorkTaskSummary> onDeleteTask;
  final ReorderCallback onReorderTasks;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isCompact ? 14 : 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(context, localizations),
          const SizedBox(height: 12),
          _buildStatusTabs(localizations),
          const SizedBox(height: 12),
          _buildSearchField(localizations),
          const SizedBox(height: 12),
          Expanded(child: _buildContent(context, localizations)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            localizations.navigationTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppGlassTokens.secondaryContent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Semantics(
          identifier: 'workTimeTrackerPage.createTaskButton', // 自动化测试用标识：创建主任务按钮
          child: FilledButton.icon(
            onPressed: state.isCreating ? null : onCreateTask,
            icon: const Icon(Icons.add, size: 18),
            label: Text(localizations.createTask),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs(AppLocalizations localizations) {
    return AppStatusFilterBar(
      selectedFilter: state.selectedFilter,
      labelBuilder: localizations.statusFilter,
      semanticIdentifierPrefix: 'workTimeTrackerPage.taskStatusTab', // 自动化测试用标识：主任务状态分类标签
      onSelected: onFilterChanged,
    );
  }

  Widget _buildSearchField(AppLocalizations localizations) {
    return Semantics(
      identifier: 'workTimeTrackerPage.taskSearchInput', // 自动化测试用标识：主任务搜索输入框
      child: TextField(
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: localizations.taskSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && !state.hasAnyTasks) {
      return _buildMessage(context, localizations.dataLoadFailed);
    }
    if (state.taskIds.isEmpty) {
      final String message = state.hasAnyTasks
          ? localizations.noMatchingTasks
          : localizations.noTasksYet;
      return _buildMessage(context, message);
    }
    return _buildTaskList();
  }

  Widget _buildMessage(BuildContext context, String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppGlassTokens.secondaryContent,
            ),
      ),
    );
  }

  Widget _buildTaskList() {
    final bool isReorderEnabled = state.selectedFilter == WorkStatusFilter.all &&
        state.searchQuery.trim().isEmpty;
    return ReorderableListView.builder(
      scrollDirection: isCompact ? Axis.horizontal : Axis.vertical,
      itemCount: state.taskIds.length,
      buildDefaultDragHandles: false,
      onReorder: isReorderEnabled
          ? onReorderTasks
          : (int oldIndex, int newIndex) {},
      itemBuilder: (BuildContext context, int index) {
        final String taskId = state.taskIds[index];
        final Widget card = _TaskCard(
          taskId: taskId,
          reorderIndex: index,
          isReorderEnabled: isReorderEnabled,
          isSelected: taskId == state.selectedTaskId,
          onSelected: () => onTaskSelected(taskId),
          onEditTask: onEditTask,
          onDeleteTask: onDeleteTask,
        );
        return Padding(
          key: ValueKey<String>(taskId),
          padding: EdgeInsets.only(
            right: isCompact ? 12 : 0,
            bottom: isCompact ? 0 : 10,
          ),
          child: isCompact
              ? SizedBox(width: 250, child: card) // 窄窗口横向任务卡宽度
              : card,
        );
      },
    );
  }
}

enum _TaskMenuAction { edit, delete }

/// 展示单个主任务；默认只显示名称，点击后再展开统计与管理操作。
class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({
    required this.taskId,
    required this.reorderIndex,
    required this.isReorderEnabled,
    required this.isSelected,
    required this.onSelected,
    required this.onEditTask,
    required this.onDeleteTask,
  });

  final String taskId;
  final int reorderIndex;
  final bool isReorderEnabled;
  final bool isSelected;
  final VoidCallback onSelected;
  final ValueChanged<WorkTaskSummary> onEditTask;
  final ValueChanged<WorkTaskSummary> onDeleteTask;

  @override
  ConsumerState<_TaskCard> createState() {
    return _TaskCardState();
  }
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WorkTaskSummary?> taskValue = ref.watch(
      taskSummaryProvider(widget.taskId),
    );
    return taskValue.when(
      data: (WorkTaskSummary? task) {
        if (task == null) {
          return const SizedBox.shrink();
        }
        return _buildCard(context, ref, task);
      },
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) {
        return Center(child: Text(AppLocalizations.of(context).dataLoadFailed));
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    WorkTaskSummary task,
  ) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ItemActionState actionState = ref.watch(
      taskItemViewModelProvider(widget.taskId),
    );
    return Semantics(
      identifier: 'workTimeTrackerPage.mainTaskCard.${task.id}', // 自动化测试用标识：主任务卡片
      button: true,
      selected: widget.isSelected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildDecoration(task),
            child: _buildContent(
              context,
              ref,
              localizations,
              task,
              actionState,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(WorkTaskSummary task) {
    return BoxDecoration(
      color: widget.isSelected
          ? AppGlassTokens.softSurface
          : AppGlassTokens.subtleSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: widget.isSelected
            ? Color(task.colorValue).withOpacity(0.35)
            : AppGlassTokens.glassBorder,
      ),
      boxShadow: widget.isSelected
          ? const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D25283A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations localizations,
    WorkTaskSummary task,
    ItemActionState actionState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildIdentity(context, localizations, task),
        if (_isExpanded) ...<Widget>[
        const SizedBox(height: 10),
        _buildStatusSelector(ref, localizations, task, actionState),
        const SizedBox(height: 8),
        Semantics(
          identifier: 'workTimeTrackerPage.taskCreatedAt.${task.id}', // 自动化测试用标识：主任务创建日期
          child: Text(
            localizations.createdOn(formatDate(task.createdAt)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppGlassTokens.secondaryContent,
                ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          formatDuration(task.completedSeconds),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          localizations.subtaskCount(task.subtaskCount),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppGlassTokens.secondaryContent,
              ),
        ),
        if (actionState.errorMessage != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(localizations.dataSaveFailed, style: const TextStyle(color: Colors.red)),
        ],
        ],
      ],
    );
  }

  Widget _buildStatusSelector(
    WidgetRef ref,
    AppLocalizations localizations,
    WorkTaskSummary task,
    ItemActionState actionState,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.taskStatusSelect.${task.id}', // 自动化测试用标识：主任务状态选择器
      child: PopupMenuButton<WorkItemStatus>(
        enabled: !actionState.isSaving,
        initialValue: task.status,
        tooltip: localizations.selectStatus,
        onSelected: (WorkItemStatus status) {
          ref.read(taskItemViewModelProvider(task.id).notifier).updateStatus(status);
        },
        itemBuilder: (BuildContext context) {
          return WorkItemStatus.values.map((WorkItemStatus status) {
            return PopupMenuItem<WorkItemStatus>(
              value: status,
              child: Semantics(
                identifier: 'workTimeTrackerPage.taskStatusOption.${task.id}.${status.name}', // 自动化测试用标识：主任务状态选项
                child: Text(localizations.workItemStatus(status)),
              ),
            );
          }).toList(growable: false);
        },
        child: Text(localizations.workItemStatus(task.status)),
      ),
    );
  }

  Widget _buildIdentity(
    BuildContext context,
    AppLocalizations localizations,
    WorkTaskSummary task,
  ) {
    return Row(
      children: <Widget>[
        if (_isExpanded) ...<Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(task.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (task.hasRunningSubtask)
          Icon(Icons.graphic_eq, size: 18, color: Color(task.colorValue)),
        if (widget.isReorderEnabled)
          Semantics(
            identifier: 'workTimeTrackerPage.taskDragHandle.${task.id}', // 自动化测试用标识：主任务拖动排序手柄
            child: ReorderableDragStartListener(
              index: widget.reorderIndex,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: AppGlassTokens.tertiaryContent,
                  semanticLabel: localizations.dragToReorder,
                ),
              ),
            ),
          ),
        if (_isExpanded) _buildMoreMenu(localizations, task),
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 20,
          color: AppGlassTokens.secondaryContent,
        ),
      ],
    );
  }

  Widget _buildMoreMenu(
    AppLocalizations localizations,
    WorkTaskSummary task,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.taskMoreButton.${task.id}', // 自动化测试用标识：主任务更多操作按钮
      child: PopupMenuButton<_TaskMenuAction>(
        tooltip: localizations.moreActions,
        onSelected: (_TaskMenuAction action) {
          switch (action) {
            case _TaskMenuAction.edit:
              widget.onEditTask(task);
              return;
            case _TaskMenuAction.delete:
              widget.onDeleteTask(task);
              return;
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<_TaskMenuAction>>[
          PopupMenuItem<_TaskMenuAction>(
            value: _TaskMenuAction.edit,
            child: Semantics(
              identifier: 'workTimeTrackerPage.editTaskAction.${task.id}', // 自动化测试用标识：重新编辑主任务操作
              child: Text(localizations.edit),
            ),
          ),
          PopupMenuItem<_TaskMenuAction>(
            value: _TaskMenuAction.delete,
            child: Semantics(
              identifier: 'workTimeTrackerPage.deleteTaskAction.${task.id}', // 自动化测试用标识：删除主任务操作
              child: Text(localizations.delete),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    widget.onSelected();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
}
