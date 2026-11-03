import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/task_list_state.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 管理主任务列表的加载、筛选、选择以及增删改排序操作。
class TaskListViewModel extends StateNotifier<TaskListState> {
  TaskListViewModel({
    required TimeTrackerRepository repository,
  })  : _repository = repository,
        super(TaskListState.initial());

  static const Duration _searchDebounceDuration =
      Duration(milliseconds: 250); // 输入停止后再查询，避免每次按键访问数据库
  static const List<int> _taskColorValues = <int>[
    0xFF5B5CE2,
    0xFF00A389,
    0xFFFF8A4C,
    0xFFE15B8D,
  ];

  final TimeTrackerRepository _repository;
  Timer? _searchDebounce;
  int _loadVersion = 0;
  bool _isMutating = false;

  Future<void> initialize() async {
    final int loadVersion = _beginLoad();
    state = state.copyWith(isLoading: true, shouldClearError: true);
    try {
      await _repository.initialize();
      if (!_canCommit(loadVersion)) {
        return;
      }
      final bool hasAnyTasks = await _repository.hasTasks();
      final List<String> taskIds = await _loadTaskIds();
      final String? savedTaskId = await _repository.getSelectedTaskId();
      final String? selectedTaskId = _resolveSelection(
        taskIds,
        savedTaskId,
        hasAnyTasks,
      );
      await _repository.saveSelectedTaskId(selectedTaskId);
      if (!_canCommit(loadVersion)) {
        return;
      }
      state = state.copyWith(
        taskIds: taskIds,
        selectedTaskId: selectedTaskId,
        shouldClearSelection: selectedTaskId == null,
        hasAnyTasks: hasAnyTasks,
        isLoading: false,
      );
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(loadVersion)) {
        return;
      }
      debugPrint('加载任务列表失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, errorMessage: '$error');
    }
  }

  Future<void> selectTask(String taskId) async {
    if (taskId == state.selectedTaskId) {
      return;
    }
    state = state.copyWith(selectedTaskId: taskId);
    try {
      await _repository.saveSelectedTaskId(taskId);
    } on Exception catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      debugPrint('保存当前任务选择失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(errorMessage: '$error');
    }
  }

  Future<void> setFilter(WorkStatusFilter filter) async {
    if (filter == state.selectedFilter) {
      return;
    }
    state = state.copyWith(selectedFilter: filter);
    await refresh();
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      unawaited(refresh());
    });
  }

  Future<void> createTask(String title, WorkItemStatus status) async {
    if (state.isCreating) {
      return;
    }
    state = state.copyWith(isCreating: true, shouldClearError: true);
    final DateTime createdAt = DateTime.now();
    try {
      final String taskId = await _repository.createTask(
        title: title,
        colorValue: _getTaskColor(createdAt),
        status: status,
        createdAt: createdAt,
      );
      if (!mounted) {
        return;
      }
      await _repository.saveSelectedTaskId(taskId);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        selectedTaskId: taskId,
        hasAnyTasks: true,
        isCreating: false,
      );
    } on Exception catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      debugPrint('创建任务失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(isCreating: false, errorMessage: '$error');
    }
  }

  Future<void> updateTaskTitle(String taskId, String title) async {
    await _runMutation(
      action: () => _repository.updateTaskTitle(
        taskId: taskId,
        title: title.trim(),
      ),
      errorContext: '修改任务名称失败',
    );
  }

  Future<void> deleteTask(String taskId) async {
    if (_isMutating) {
      return;
    }
    _isMutating = true;
    try {
      await _repository.deleteTask(taskId);
      final bool hasAnyTasks = await _repository.hasTasks();
      final List<String> taskIds = await _loadTaskIds();
      final String? selectedTaskId = state.selectedTaskId == taskId
          ? (taskIds.isEmpty ? null : taskIds.first)
          : state.selectedTaskId;
      await _repository.saveSelectedTaskId(selectedTaskId);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        taskIds: taskIds,
        selectedTaskId: selectedTaskId,
        shouldClearSelection: selectedTaskId == null,
        hasAnyTasks: hasAnyTasks,
        shouldClearError: true,
      );
    } on Exception catch (error, stackTrace) {
      _handleMutationError('删除任务失败', error, stackTrace);
    } finally {
      _isMutating = false;
    }
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (!canReorder || _isMutating) {
      return;
    }
    final List<String> originalIds = state.taskIds;
    final List<String> reorderedIds = List<String>.of(originalIds);
    final int targetIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    reorderedIds.insert(targetIndex, reorderedIds.removeAt(oldIndex));
    state = state.copyWith(taskIds: reorderedIds, shouldClearError: true);
    _isMutating = true;
    try {
      await _repository.reorderTasks(reorderedIds);
    } on Exception catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(taskIds: originalIds, errorMessage: '$error');
      }
      debugPrint('调整任务顺序失败：$error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isMutating = false;
    }
  }

  bool get canReorder {
    return state.selectedFilter == WorkStatusFilter.all &&
        state.searchQuery.trim().isEmpty;
  }

  Future<void> refresh() async {
    final int loadVersion = _beginLoad();
    try {
      final List<String> taskIds = await _loadTaskIds();
      if (!_canCommit(loadVersion)) {
        return;
      }
      state = state.copyWith(taskIds: taskIds, shouldClearError: true);
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(loadVersion)) {
        return;
      }
      debugPrint('刷新任务列表失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(errorMessage: '$error');
    }
  }

  Future<void> _runMutation({
    required Future<void> Function() action,
    required String errorContext,
  }) async {
    if (_isMutating) {
      return;
    }
    _isMutating = true;
    try {
      await action();
      if (mounted) {
        state = state.copyWith(shouldClearError: true);
      }
    } on Exception catch (error, stackTrace) {
      _handleMutationError(errorContext, error, stackTrace);
    } finally {
      _isMutating = false;
    }
  }

  void _handleMutationError(
    String context,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('$context：$error');
    debugPrintStack(stackTrace: stackTrace);
    if (mounted) {
      state = state.copyWith(errorMessage: '$error');
    }
  }

  Future<List<String>> _loadTaskIds() {
    return _repository.getTaskIds(
      query: state.searchQuery,
      status: state.selectedFilter.status,
    );
  }

  String? _resolveSelection(
    List<String> taskIds,
    String? savedTaskId,
    bool hasAnyTasks,
  ) {
    if (!hasAnyTasks) {
      return null;
    }
    if (savedTaskId != null && taskIds.contains(savedTaskId)) {
      return savedTaskId;
    }
    return taskIds.isEmpty ? null : taskIds.first;
  }

  int _getTaskColor(DateTime createdAt) {
    final int index = createdAt.microsecondsSinceEpoch % _taskColorValues.length;
    return _taskColorValues[index];
  }

  int _beginLoad() {
    _loadVersion += 1;
    return _loadVersion;
  }

  bool _canCommit(int loadVersion) {
    return mounted && loadVersion == _loadVersion;
  }

  @override
  void dispose() {
    _loadVersion += 1;
    _searchDebounce?.cancel();
    super.dispose();
  }
}
