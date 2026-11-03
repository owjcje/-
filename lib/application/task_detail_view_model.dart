import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/task_detail_state.dart';
import 'package:work_time_tracker/application/work_status_filter.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 管理所选主任务下的子任务筛选、创建、编辑、删除与拖动排序。
class TaskDetailViewModel extends StateNotifier<TaskDetailState> {
  TaskDetailViewModel({
    required String taskId,
    required TimeTrackerRepository repository,
  })  : _repository = repository,
        super(TaskDetailState.initial(taskId));

  static const Duration _searchDebounceDuration =
      Duration(milliseconds: 250); // 输入停止后再查询，避免连续访问数据库
  final TimeTrackerRepository _repository;
  Timer? _searchDebounce;
  int _loadVersion = 0;
  bool _isMutating = false;

  Future<void> initialize() async {
    await _loadSubtasks(isInitialLoad: true);
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

  Future<void> createSubtask(String title, WorkItemStatus status) async {
    if (state.isCreating) {
      return;
    }
    state = state.copyWith(isCreating: true, shouldClearError: true);
    try {
      await _repository.createSubtask(
        taskId: state.taskId,
        title: title,
        status: status,
        createdAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(hasAnySubtasks: true, isCreating: false);
    } on Exception catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      debugPrint('创建子任务失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(isCreating: false, errorMessage: '$error');
    }
  }

  Future<void> updateSubtaskTitle(String subtaskId, String title) async {
    await _runMutation(
      action: () => _repository.updateSubtaskTitle(
        subtaskId: subtaskId,
        title: title.trim(),
      ),
      errorContext: '修改子任务名称失败',
    );
  }

  Future<void> updateSubtaskNote(String subtaskId, String note) async {
    await _runMutation(
      action: () => _repository.updateSubtaskNote(
        subtaskId: subtaskId,
        note: note.trim(),
      ),
      errorContext: '修改子任务备注失败',
    );
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await _runMutation(
      action: () async {
        await _repository.deleteSubtask(subtaskId);
        await refresh();
      },
      errorContext: '删除子任务失败',
    );
  }

  Future<void> reorderSubtasks(int oldIndex, int newIndex) async {
    if (!canReorder || _isMutating) {
      return;
    }
    final List<String> originalIds = state.subtaskIds;
    final List<String> reorderedIds = List<String>.of(originalIds);
    final int targetIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    reorderedIds.insert(targetIndex, reorderedIds.removeAt(oldIndex));
    state = state.copyWith(subtaskIds: reorderedIds, shouldClearError: true);
    _isMutating = true;
    try {
      await _repository.reorderSubtasks(
        taskId: state.taskId,
        subtaskIds: reorderedIds,
      );
    } on Exception catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(subtaskIds: originalIds, errorMessage: '$error');
      }
      debugPrint('调整子任务顺序失败：$error');
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
    await _loadSubtasks(isInitialLoad: false);
  }

  Future<void> _loadSubtasks({required bool isInitialLoad}) async {
    final int loadVersion = _beginLoad();
    if (isInitialLoad) {
      state = state.copyWith(isLoading: true, shouldClearError: true);
    }
    try {
      final List<String> subtaskIds = await _repository.getSubtaskIds(
        taskId: state.taskId,
        query: state.searchQuery,
        status: state.selectedFilter.status,
      );
      if (!_canCommit(loadVersion)) {
        return;
      }
      state = state.copyWith(
        subtaskIds: subtaskIds,
        hasAnySubtasks: isInitialLoad || canReorder
            ? subtaskIds.isNotEmpty
            : state.hasAnySubtasks,
        isLoading: false,
        shouldClearError: true,
      );
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(loadVersion)) {
        return;
      }
      debugPrint('加载子任务列表失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, errorMessage: '$error');
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
      debugPrint('$errorContext：$error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        state = state.copyWith(errorMessage: '$error');
      }
    } finally {
      _isMutating = false;
    }
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
