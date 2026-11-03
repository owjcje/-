import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/application/subtask_item_view_model.dart';
import 'package:work_time_tracker/application/task_detail_state.dart';
import 'package:work_time_tracker/application/task_detail_view_model.dart';
import 'package:work_time_tracker/application/task_item_view_model.dart';
import 'package:work_time_tracker/application/task_list_state.dart';
import 'package:work_time_tracker/application/task_list_view_model.dart';
import 'package:work_time_tracker/application/time_entry_list_state.dart';
import 'package:work_time_tracker/application/time_entry_list_view_model.dart';
import 'package:work_time_tracker/application/work_time_export_view_model.dart';
import 'package:work_time_tracker/data/services/work_time_export_service.dart';
import 'package:work_time_tracker/data/repositories/local_time_tracker_repository.dart';
import 'package:work_time_tracker/domain/entities/work_data_event.dart';
import 'package:work_time_tracker/domain/entities/work_subtask_summary.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';
import 'package:work_time_tracker/domain/use_cases/start_subtask_tracking.dart';
import 'package:work_time_tracker/domain/use_cases/stop_subtask_tracking.dart';
import 'package:work_time_tracker/domain/use_cases/update_time_entry.dart';

// 数据层依赖入口：全局复用同一个本地 Repository 实例。
final Provider<TimeTrackerRepository> timeTrackerRepositoryProvider =
    Provider<TimeTrackerRepository>((ProviderRef<TimeTrackerRepository> ref) {
  return LocalTimeTrackerRepository.instance;
});

// 文件导出服务入口：复用同一个 Excel 写入与系统保存对话框服务。
final Provider<WorkTimeExportService> workTimeExportServiceProvider =
    Provider<WorkTimeExportService>((ProviderRef<WorkTimeExportService> ref) {
  return WorkTimeExportService.instance;
});

final StateNotifierProvider<WorkTimeExportViewModel, ItemActionState>
    workTimeExportViewModelProvider =
    StateNotifierProvider<WorkTimeExportViewModel, ItemActionState>(
  (StateNotifierProviderRef<WorkTimeExportViewModel, ItemActionState> ref) {
    return WorkTimeExportViewModel(
      repository: ref.read(timeTrackerRepositoryProvider),
      exportService: ref.read(workTimeExportServiceProvider),
    );
  },
);

final StreamProvider<WorkDataEvent> workDataChangesProvider =
    StreamProvider<WorkDataEvent>((StreamProviderRef<WorkDataEvent> ref) {
  return ref.read(timeTrackerRepositoryProvider).changes;
});

// 数据变化协调器：根据事件精确刷新列表、聚合数据和计时明细。
final Provider<void> workDataCoordinatorProvider =
    Provider<void>((ProviderRef<void> ref) {
  ref.listen<AsyncValue<WorkDataEvent>>(
    workDataChangesProvider,
    (
      AsyncValue<WorkDataEvent>? _,
      AsyncValue<WorkDataEvent> next,
    ) {
      next.whenData((WorkDataEvent event) {
        _handleWorkDataEvent(ref, event);
      });
    },
  );
});

final AutoDisposeFutureProviderFamily<WorkTaskSummary?, String>
    taskSummaryProvider =
    FutureProvider.autoDispose.family<WorkTaskSummary?, String>(
  (AutoDisposeFutureProviderRef<WorkTaskSummary?> ref, String taskId) {
    return ref.read(timeTrackerRepositoryProvider).getTaskSummary(taskId);
  },
);

final AutoDisposeFutureProviderFamily<WorkSubtaskSummary?, String>
    subtaskSummaryProvider =
    FutureProvider.autoDispose.family<WorkSubtaskSummary?, String>(
  (AutoDisposeFutureProviderRef<WorkSubtaskSummary?> ref, String subtaskId) {
    return ref
        .read(timeTrackerRepositoryProvider)
        .getSubtaskSummary(subtaskId);
  },
);

final StateNotifierProvider<TaskListViewModel, TaskListState>
    taskListViewModelProvider =
    StateNotifierProvider<TaskListViewModel, TaskListState>(
  (StateNotifierProviderRef<TaskListViewModel, TaskListState> ref) {
    final TaskListViewModel viewModel = TaskListViewModel(
      repository: ref.read(timeTrackerRepositoryProvider),
    );
    unawaited(viewModel.initialize());
    return viewModel;
  },
);

final AutoDisposeStateNotifierProviderFamily<
    TaskDetailViewModel,
    TaskDetailState,
    String> taskDetailViewModelProvider = StateNotifierProvider.autoDispose
    .family<TaskDetailViewModel, TaskDetailState, String>(
  (
    AutoDisposeStateNotifierProviderRef<TaskDetailViewModel, TaskDetailState>
        ref,
    String taskId,
  ) {
    final TaskDetailViewModel viewModel = TaskDetailViewModel(
      taskId: taskId,
      repository: ref.read(timeTrackerRepositoryProvider),
    );
    unawaited(viewModel.initialize());
    return viewModel;
  },
);

final AutoDisposeStateNotifierProviderFamily<
    TaskItemViewModel,
    ItemActionState,
    String> taskItemViewModelProvider = StateNotifierProvider.autoDispose
    .family<TaskItemViewModel, ItemActionState, String>(
  (
    AutoDisposeStateNotifierProviderRef<TaskItemViewModel, ItemActionState> ref,
    String taskId,
  ) {
    return TaskItemViewModel(
      taskId: taskId,
      repository: ref.read(timeTrackerRepositoryProvider),
    );
  },
);

final AutoDisposeStateNotifierProviderFamily<
    SubtaskItemViewModel,
    ItemActionState,
    String> subtaskItemViewModelProvider = StateNotifierProvider.autoDispose
    .family<SubtaskItemViewModel, ItemActionState, String>(
  (
    AutoDisposeStateNotifierProviderRef<SubtaskItemViewModel, ItemActionState>
        ref,
    String subtaskId,
  ) {
    final TimeTrackerRepository repository = ref.read(
      timeTrackerRepositoryProvider,
    );
    return SubtaskItemViewModel(
      subtaskId: subtaskId,
      repository: repository,
      startTrackingUseCase: StartSubtaskTrackingUseCase(
        repository: repository,
      ),
      stopTrackingUseCase: StopSubtaskTrackingUseCase(
        repository: repository,
      ),
    );
  },
);

final AutoDisposeStateNotifierProviderFamily<
    TimeEntryListViewModel,
    TimeEntryListState,
    String> timeEntryListViewModelProvider = StateNotifierProvider.autoDispose
    .family<TimeEntryListViewModel, TimeEntryListState, String>(
  (
    AutoDisposeStateNotifierProviderRef<
            TimeEntryListViewModel, TimeEntryListState>
        ref,
    String subtaskId,
  ) {
    final TimeEntryListViewModel viewModel = TimeEntryListViewModel(
      subtaskId: subtaskId,
      repository: ref.read(timeTrackerRepositoryProvider),
      updateTimeEntryUseCase: UpdateTimeEntryUseCase(
        repository: ref.read(timeTrackerRepositoryProvider),
      ),
    );
    unawaited(viewModel.initialize());
    return viewModel;
  },
);

void _handleWorkDataEvent(Ref ref, WorkDataEvent event) {
  switch (event) {
    case TaskCreatedEvent(:final String taskId):
      ref.invalidate(taskSummaryProvider(taskId));
      _refreshTaskList(ref);
    case SubtaskCreatedEvent(
        :final String taskId,
        :final String subtaskId,
      ):
      ref.invalidate(taskSummaryProvider(taskId));
      ref.invalidate(subtaskSummaryProvider(subtaskId));
      _refreshSelectedTaskDetail(ref, <String>{taskId});
    case TaskDeletedEvent(:final String taskId):
      ref.invalidate(taskSummaryProvider(taskId));
      _refreshTaskList(ref);
    case SubtaskDeletedEvent(
        :final String taskId,
        :final String subtaskId,
      ):
      ref.invalidate(taskSummaryProvider(taskId));
      ref.invalidate(subtaskSummaryProvider(subtaskId));
      _refreshSelectedTaskDetail(ref, <String>{taskId});
    case WorkItemsChangedEvent(
        :final Set<String> taskIds,
        :final Set<String> subtaskIds,
        :final bool shouldRefreshTimeEntries,
      ):
      _refreshChangedItems(
        ref,
        taskIds,
        subtaskIds,
        shouldRefreshTimeEntries,
      );
  }
}

void _refreshChangedItems(
  Ref ref,
  Set<String> taskIds,
  Set<String> subtaskIds,
  bool shouldRefreshTimeEntries,
) {
  for (final String taskId in taskIds) {
    ref.invalidate(taskSummaryProvider(taskId));
  }
  for (final String subtaskId in subtaskIds) {
    ref.invalidate(subtaskSummaryProvider(subtaskId));
    if (shouldRefreshTimeEntries) {
      ref.invalidate(timeEntryListViewModelProvider(subtaskId));
    }
  }
  _refreshSelectedTaskDetail(ref, taskIds);
  _refreshTaskList(ref);
}

void _refreshSelectedTaskDetail(Ref ref, Set<String> affectedTaskIds) {
  final String? selectedTaskId =
      ref.read(taskListViewModelProvider).selectedTaskId;
  if (selectedTaskId == null || !affectedTaskIds.contains(selectedTaskId)) {
    return;
  }
  unawaited(
    ref.read(taskDetailViewModelProvider(selectedTaskId).notifier).refresh(),
  );
}

void _refreshTaskList(Ref ref) {
  unawaited(ref.read(taskListViewModelProvider.notifier).refresh());
}
