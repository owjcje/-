import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/task_list_state.dart';
import 'package:work_time_tracker/application/time_tracker_providers.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/data/services/work_time_export_service.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';
import 'package:work_time_tracker/core/theme/app_glass_tokens.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/entities/work_subtask_summary.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/domain/entities/work_time_export_request.dart';
import 'package:work_time_tracker/l10n/app_localizations.dart';
import 'package:work_time_tracker/presentation/widgets/create_work_item_dialog.dart';
import 'package:work_time_tracker/presentation/widgets/task_detail_panel.dart';
import 'package:work_time_tracker/presentation/widgets/task_sidebar.dart';
import 'package:work_time_tracker/presentation/widgets/design/glass_background.dart';
import 'package:work_time_tracker/presentation/widgets/design/glass_dialog.dart';
import 'package:work_time_tracker/presentation/widgets/design/glass_surface.dart';
import 'package:work_time_tracker/presentation/widgets/work_item_management_dialogs.dart';
import 'package:work_time_tracker/presentation/widgets/work_time_export_dialog.dart';

/// 工时记录主页面，协调主任务导航、子任务详情与管理弹窗。
class WorkTimeTrackerPage extends ConsumerStatefulWidget {
  const WorkTimeTrackerPage({super.key});

  @override
  ConsumerState<WorkTimeTrackerPage> createState() {
    return _WorkTimeTrackerPageState();
  }
}

class _WorkTimeTrackerPageState extends ConsumerState<WorkTimeTrackerPage> {
  @override
  Widget build(BuildContext context) {
    ref.watch(workDataCoordinatorProvider);
    final AppLocalizations localizations = AppLocalizations.of(context);
    final TaskListState taskListState = ref.watch(taskListViewModelProvider);
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildApplicationHeader(localizations),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return constraints.maxWidth >= 900 // 桌面端左右分栏断点
                        ? _buildWideLayout(taskListState)
                        : _buildCompactLayout(taskListState);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationHeader(AppLocalizations localizations) {
    final ItemActionState exportState = ref.watch(
      workTimeExportViewModelProvider,
    );
    return GlassSurface(
      isBlurred: true,
      borderRadius: BorderRadius.zero,
      color: AppGlassTokens.softSurface,
      child: SizedBox(
        height: 72, // 桌面端标题栏高度
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                localizations.appTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Semantics(
                identifier: 'workTimeTrackerPage.exportWorkTimeButton', // 自动化测试用标识：导出工时 Excel 按钮
                child: OutlinedButton.icon(
                  onPressed: exportState.isSaving ? null : _showExportDialog,
                  icon: exportState.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(localizations.export),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  localizations.localStorageNotice,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppGlassTokens.secondaryContent,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(TaskListState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 360, // 桌面端主任务导航固定宽度
            child: GlassSurface(
              isBlurred: true,
              color: AppGlassTokens.softSurface,
              child: _buildTaskSidebar(state, false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GlassSurface(child: _buildTaskDetail(state)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(TaskListState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 420, // 窄窗口为展开后的主任务详情预留完整显示高度
            child: GlassSurface(
              isBlurred: true,
              color: AppGlassTokens.softSurface,
              child: _buildTaskSidebar(state, true),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GlassSurface(child: _buildTaskDetail(state)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSidebar(TaskListState state, bool isCompact) {
    return TaskSidebar(
      state: state,
      isCompact: isCompact,
      onTaskSelected: (String taskId) {
        ref.read(taskListViewModelProvider.notifier).selectTask(taskId);
      },
      onFilterChanged: (WorkStatusFilter filter) {
        ref.read(taskListViewModelProvider.notifier).setFilter(filter);
      },
      onSearchChanged: (String query) {
        ref.read(taskListViewModelProvider.notifier).search(query);
      },
      onCreateTask: _showCreateTaskDialog,
      onEditTask: _showEditTaskDialog,
      onDeleteTask: _showDeleteTaskDialog,
      onReorderTasks: (int oldIndex, int newIndex) {
        ref
            .read(taskListViewModelProvider.notifier)
            .reorderTasks(oldIndex, newIndex);
      },
    );
  }

  Widget _buildTaskDetail(TaskListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final String? taskId = state.selectedTaskId;
    if (taskId == null) {
      return _buildNoTaskSelected();
    }
    return TaskDetailPanel(
      taskId: taskId,
      onCreateSubtask: () => _showCreateSubtaskDialog(taskId),
      onEditSubtask: _showEditSubtaskDialog,
      onEditSubtaskNote: _showEditSubtaskNoteDialog,
      onDeleteSubtask: _showDeleteSubtaskDialog,
    );
  }

  Widget _buildNoTaskSelected() {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppGlassTokens.tertiaryContent,
          ),
          const SizedBox(height: 12),
          Text(localizations.noTaskSelected),
        ],
      ),
    );
  }

  Future<void> _showCreateTaskDialog() async {
    final CreateWorkItemResult? result = await showDialog<CreateWorkItemResult>(
      context: context,
      builder: (BuildContext context) {
        return const GlassDialog(
          child: CreateWorkItemDialog(isSubtask: false),
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    await ref
        .read(taskListViewModelProvider.notifier)
        .createTask(result.title, result.status);
  }

  Future<void> _showExportDialog() async {
    final List<WorkTaskSummary> tasks = await ref
        .read(workTimeExportViewModelProvider.notifier)
        .loadTaskOptions();
    if (!mounted) {
      return;
    }
    if (tasks.isEmpty) {
      final ItemActionState exportState = ref.read(
        workTimeExportViewModelProvider,
      );
      _showExportMessage(
        exportState.errorMessage == null
            ? AppLocalizations.of(context).noTasksAvailableForExport
            : AppLocalizations.of(context).exportFailed,
      );
      return;
    }
    final TaskListState taskListState = ref.read(taskListViewModelProvider);
    final WorkTimeExportRequest? exportRequest =
        await showDialog<WorkTimeExportRequest>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(
          child: WorkTimeExportDialog(
            tasks: tasks,
            initialSelectedTaskId: taskListState.selectedTaskId,
          ),
        );
      },
    );
    if (exportRequest == null || exportRequest.taskIds.isEmpty || !mounted) {
      return;
    }
    final String? savedPath = await ref
        .read(workTimeExportViewModelProvider.notifier)
        .export(
          taskIds: exportRequest.taskIds,
          startDate: exportRequest.startDate,
          endDate: exportRequest.endDate,
          labels: _buildExportLabels(AppLocalizations.of(context)),
        );
    if (!mounted) {
      return;
    }
    final ItemActionState exportState = ref.read(
      workTimeExportViewModelProvider,
    );
    if (savedPath != null) {
      _showExportMessage(AppLocalizations.of(context).exportCompleted);
      return;
    }
    if (exportState.errorMessage != null) {
      _showExportMessage(AppLocalizations.of(context).exportFailed);
    }
  }

  void _showExportMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  WorkTimeExportLabels _buildExportLabels(
    AppLocalizations localizations,
  ) {
    return WorkTimeExportLabels(
      summarySheetName: localizations.exportSummarySheetName,
      detailSheetName: localizations.exportDetailSheetName,
      taskColumn: localizations.exportTaskColumn,
      totalDurationColumn: localizations.exportTotalDurationColumn,
      subtaskCountColumn: localizations.exportSubtaskCountColumn,
      subtaskColumn: localizations.exportSubtaskColumn,
      subtaskNoteColumn: localizations.exportSubtaskNoteColumn,
      subtaskDurationColumn: localizations.exportSubtaskDurationColumn,
      entryNumberColumn: localizations.exportEntryNumberColumn,
      entryDurationColumn: localizations.exportEntryDurationColumn,
      firstStartedAtColumn: localizations.exportFirstStartedAtColumn,
      lastEndedAtColumn: localizations.exportLastEndedAtColumn,
      excelFileTypeLabel: localizations.excelFileTypeLabel,
      fileNamePrefix: localizations.exportFileNamePrefix,
      emptyValue: localizations.exportEmptyValue,
    );
  }

  Future<void> _showCreateSubtaskDialog(String taskId) async {
    final CreateWorkItemResult? result = await showDialog<CreateWorkItemResult>(
      context: context,
      builder: (BuildContext context) {
        return const GlassDialog(
          child: CreateWorkItemDialog(isSubtask: true),
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    await ref
        .read(taskDetailViewModelProvider(taskId).notifier)
        .createSubtask(result.title, result.status);
  }

  Future<void> _showEditTaskDialog(WorkTaskSummary task) async {
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(
          child: EditWorkItemTitleDialog(
            initialTitle: task.title,
            isSubtask: false,
          ),
        );
      },
    );
    if (title == null || title == task.title || !mounted) {
      return;
    }
    await ref
        .read(taskListViewModelProvider.notifier)
        .updateTaskTitle(task.id, title);
  }

  Future<void> _showDeleteTaskDialog(WorkTaskSummary task) async {
    final bool shouldDelete = await _confirmDeletion(
      title: task.title,
      isSubtask: false,
    );
    if (!shouldDelete || !mounted) {
      return;
    }
    await ref.read(taskListViewModelProvider.notifier).deleteTask(task.id);
  }

  Future<void> _showEditSubtaskDialog(WorkSubtaskSummary subtask) async {
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(
          child: EditWorkItemTitleDialog(
            initialTitle: subtask.title,
            isSubtask: true,
          ),
        );
      },
    );
    if (title == null || title == subtask.title || !mounted) {
      return;
    }
    await ref
        .read(taskDetailViewModelProvider(subtask.taskId).notifier)
        .updateSubtaskTitle(subtask.id, title);
  }

  Future<void> _showDeleteSubtaskDialog(WorkSubtaskSummary subtask) async {
    final bool shouldDelete = await _confirmDeletion(
      title: subtask.title,
      isSubtask: true,
    );
    if (!shouldDelete || !mounted) {
      return;
    }
    await ref
        .read(taskDetailViewModelProvider(subtask.taskId).notifier)
        .deleteSubtask(subtask.id);
  }

  Future<void> _showEditSubtaskNoteDialog(WorkSubtaskSummary subtask) async {
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(
          child: EditSubtaskNoteDialog(initialNote: subtask.note),
        );
      },
    );
    if (note == null || note == subtask.note || !mounted) {
      return;
    }
    await ref
        .read(taskDetailViewModelProvider(subtask.taskId).notifier)
        .updateSubtaskNote(subtask.id, note);
  }

  Future<bool> _confirmDeletion({
    required String title,
    required bool isSubtask,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialog(
          child: DeleteWorkItemDialog(
            title: title,
            isSubtask: isSubtask,
          ),
        );
      },
    );
    return result ?? false;
  }
}
