import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/task_detail_state.dart';
import 'package:work_time_tracker/application/time_tracker_providers.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';
import 'package:work_time_tracker/domain/entities/work_subtask_summary.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';
import 'package:work_time_tracker/presentation/widgets/task_summary_header.dart';
import 'package:work_time_tracker/presentation/widgets/work_subtask_card.dart';
import 'package:work_time_tracker/presentation/widgets/design/app_status_filter_bar.dart';

/// 展示所选主任务概览，并管理其子任务筛选与排序列表。
class TaskDetailPanel extends ConsumerWidget {
  const TaskDetailPanel({
    required this.taskId,
    required this.onCreateSubtask,
    required this.onEditSubtask,
    required this.onEditSubtaskNote,
    required this.onDeleteSubtask,
    super.key,
  });

  final String taskId;
  final VoidCallback onCreateSubtask;
  final ValueChanged<WorkSubtaskSummary> onEditSubtask;
  final ValueChanged<WorkSubtaskSummary> onEditSubtaskNote;
  final ValueChanged<WorkSubtaskSummary> onDeleteSubtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkTaskSummary?> taskValue = ref.watch(
      taskSummaryProvider(taskId),
    );
    final TaskDetailState detailState = ref.watch(
      taskDetailViewModelProvider(taskId),
    );
    return taskValue.when(
      data: (WorkTaskSummary? task) {
        return task == null
            ? _buildUnavailable(context)
            : _buildDetail(context, ref, task, detailState);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) {
        return _buildUnavailable(context);
      },
    );
  }

  Widget _buildDetail(
    BuildContext context,
    WidgetRef ref,
    WorkTaskSummary task,
    TaskDetailState state,
  ) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040), // 内容区最大可读宽度
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16), // 紧凑列表内容留白
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TaskSummaryHeader(task: task),
              const SizedBox(height: 16),
              _buildSectionHeader(context, localizations, state),
              const SizedBox(height: 8),
              _buildStatusTabs(ref, localizations, state),
              const SizedBox(height: 8),
              _buildSearchField(ref, localizations),
              const SizedBox(height: 8),
              Expanded(child: _buildSubtaskContent(context, ref, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    AppLocalizations localizations,
    TaskDetailState state,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            localizations.subtaskList,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Semantics(
          identifier: 'workTimeTrackerPage.createSubtaskButton', // 自动化测试用标识：创建子任务按钮
          child: FilledButton.icon(
            onPressed: state.isCreating ? null : onCreateSubtask,
            icon: const Icon(Icons.add, size: 18),
            label: Text(localizations.createSubtask),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs(
    WidgetRef ref,
    AppLocalizations localizations,
    TaskDetailState state,
  ) {
    return AppStatusFilterBar(
      selectedFilter: state.selectedFilter,
      labelBuilder: localizations.statusFilter,
      semanticIdentifierPrefix: 'workTimeTrackerPage.subtaskStatusTab', // 自动化测试用标识：子任务状态分类标签
      onSelected: (WorkStatusFilter filter) {
        ref.read(taskDetailViewModelProvider(taskId).notifier).setFilter(filter);
      },
    );
  }

  Widget _buildSearchField(
    WidgetRef ref,
    AppLocalizations localizations,
  ) {
    return Semantics(
      identifier: 'workTimeTrackerPage.subtaskSearchInput', // 自动化测试用标识：子任务搜索输入框
      child: TextField(
        onChanged: (String query) {
          ref.read(taskDetailViewModelProvider(taskId).notifier).search(query);
        },
        decoration: InputDecoration(
          hintText: localizations.subtaskSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
        ),
      ),
    );
  }

  Widget _buildSubtaskContent(
    BuildContext context,
    WidgetRef ref,
    TaskDetailState state,
  ) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && !state.hasAnySubtasks) {
      return _buildMessage(context, localizations.dataLoadFailed);
    }
    if (state.subtaskIds.isEmpty) {
      final String message = state.hasAnySubtasks
          ? localizations.noMatchingSubtasks
          : localizations.noSubtasksYet;
      return _buildMessage(context, message);
    }
    final bool isReorderEnabled = state.selectedFilter == WorkStatusFilter.all &&
        state.searchQuery.trim().isEmpty;
    return ReorderableListView.builder(
      itemCount: state.subtaskIds.length,
      buildDefaultDragHandles: false,
      onReorder: isReorderEnabled
          ? (int oldIndex, int newIndex) {
              ref
                  .read(taskDetailViewModelProvider(taskId).notifier)
                  .reorderSubtasks(oldIndex, newIndex);
            }
          : (int oldIndex, int newIndex) {},
      itemBuilder: (BuildContext context, int index) {
        final String subtaskId = state.subtaskIds[index];
        return Padding(
          key: ValueKey<String>(subtaskId),
          padding: EdgeInsets.zero,
          child: WorkSubtaskCard(
            subtaskId: subtaskId,
            reorderIndex: index,
            isReorderEnabled: isReorderEnabled,
            onEditSubtask: onEditSubtask,
            onEditSubtaskNote: onEditSubtaskNote,
            onDeleteSubtask: onDeleteSubtask,
          ),
        );
      },
    );
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

  Widget _buildUnavailable(BuildContext context) {
    return Center(child: Text(AppLocalizations.of(context).dataLoadFailed));
  }
}
