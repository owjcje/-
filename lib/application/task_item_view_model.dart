import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 管理单个主任务的状态切换，并向界面反馈保存结果。
class TaskItemViewModel extends StateNotifier<ItemActionState> {
  TaskItemViewModel({
    required this.taskId,
    required TimeTrackerRepository repository,
  })  : _repository = repository,
        super(const ItemActionState.idle());

  final String taskId;
  final TimeTrackerRepository _repository;
  int _operationVersion = 0;

  Future<void> updateStatus(WorkItemStatus status) async {
    if (state.isSaving) {
      return;
    }
    final int operationVersion = _beginOperation();
    state = const ItemActionState(isSaving: true, errorMessage: null);
    try {
      await _repository.updateTaskStatus(
        taskId: taskId,
        status: status,
        changedAt: DateTime.now(),
      );
      if (!_canCommit(operationVersion)) {
        return;
      }
      state = const ItemActionState.idle();
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(operationVersion)) {
        return;
      }
      debugPrint('更新任务状态失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = ItemActionState(isSaving: false, errorMessage: '$error');
    }
  }

  int _beginOperation() {
    _operationVersion += 1;
    return _operationVersion;
  }

  bool _canCommit(int operationVersion) {
    return mounted && operationVersion == _operationVersion;
  }

  @override
  void dispose() {
    _operationVersion += 1;
    super.dispose();
  }
}
