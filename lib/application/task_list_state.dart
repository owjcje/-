import 'package:work_time_tracker/application/work_status_filter.dart';

/// 主任务导航区的不可变界面状态。
class TaskListState {
  TaskListState({
    required List<String> taskIds,
    required this.selectedTaskId,
    required this.selectedFilter,
    required this.searchQuery,
    required this.hasAnyTasks,
    required this.isLoading,
    required this.isCreating,
    required this.errorMessage,
  }) : taskIds = List<String>.unmodifiable(taskIds);

  factory TaskListState.initial() {
    return TaskListState(
      taskIds: <String>[],
      selectedTaskId: null,
      selectedFilter: WorkStatusFilter.all,
      searchQuery: '',
      hasAnyTasks: false,
      isLoading: true,
      isCreating: false,
      errorMessage: null,
    );
  }

  final List<String> taskIds;
  final String? selectedTaskId;
  final WorkStatusFilter selectedFilter;
  final String searchQuery;
  final bool hasAnyTasks;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  TaskListState copyWith({
    List<String>? taskIds,
    String? selectedTaskId,
    bool shouldClearSelection = false,
    WorkStatusFilter? selectedFilter,
    String? searchQuery,
    bool? hasAnyTasks,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool shouldClearError = false,
  }) {
    return TaskListState(
      taskIds: taskIds ?? this.taskIds,
      selectedTaskId:
          shouldClearSelection ? null : selectedTaskId ?? this.selectedTaskId,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      hasAnyTasks: hasAnyTasks ?? this.hasAnyTasks,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: shouldClearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
