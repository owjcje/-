import 'package:work_time_tracker/application/work_status_filter.dart';

/// 当前主任务下子任务列表的不可变界面状态。
class TaskDetailState {
  TaskDetailState({
    required this.taskId,
    required List<String> subtaskIds,
    required this.selectedFilter,
    required this.searchQuery,
    required this.hasAnySubtasks,
    required this.isLoading,
    required this.isCreating,
    required this.errorMessage,
  }) : subtaskIds = List<String>.unmodifiable(subtaskIds);

  factory TaskDetailState.initial(String taskId) {
    return TaskDetailState(
      taskId: taskId,
      subtaskIds: <String>[],
      selectedFilter: WorkStatusFilter.all,
      searchQuery: '',
      hasAnySubtasks: false,
      isLoading: true,
      isCreating: false,
      errorMessage: null,
    );
  }

  final String taskId;
  final List<String> subtaskIds;
  final WorkStatusFilter selectedFilter;
  final String searchQuery;
  final bool hasAnySubtasks;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  TaskDetailState copyWith({
    List<String>? subtaskIds,
    WorkStatusFilter? selectedFilter,
    String? searchQuery,
    bool? hasAnySubtasks,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool shouldClearError = false,
  }) {
    return TaskDetailState(
      taskId: taskId,
      subtaskIds: subtaskIds ?? this.subtaskIds,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      hasAnySubtasks: hasAnySubtasks ?? this.hasAnySubtasks,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: shouldClearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
