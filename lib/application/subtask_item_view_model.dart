import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/domain/entities/tracking_change_result.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';
import 'package:work_time_tracker/domain/use_cases/start_subtask_tracking.dart';
import 'package:work_time_tracker/domain/use_cases/stop_subtask_tracking.dart';

/// 管理单个子任务的状态切换以及开始、停止计时流程。
class SubtaskItemViewModel extends StateNotifier<ItemActionState> {
  SubtaskItemViewModel({
    required this.subtaskId,
    required TimeTrackerRepository repository,
    required StartSubtaskTrackingUseCase startTrackingUseCase,
    required StopSubtaskTrackingUseCase stopTrackingUseCase,
  })  : _repository = repository,
        _startTrackingUseCase = startTrackingUseCase,
        _stopTrackingUseCase = stopTrackingUseCase,
        super(const ItemActionState.idle());

  final String subtaskId;
  final TimeTrackerRepository _repository;
  final StartSubtaskTrackingUseCase _startTrackingUseCase;
  final StopSubtaskTrackingUseCase _stopTrackingUseCase;
  int _operationVersion = 0;

  Future<void> updateStatus(WorkItemStatus status) async {
    await _runAction(() {
      return _repository.updateSubtaskStatus(
        subtaskId: subtaskId,
        status: status,
        changedAt: DateTime.now(),
      );
    });
  }

  Future<void> startTracking() async {
    await _runAction(() {
      return _startTrackingUseCase.execute(
        subtaskId: subtaskId,
        startedAt: DateTime.now(),
      );
    });
  }

  Future<void> stopTracking() async {
    await _runAction(() {
      return _stopTrackingUseCase.execute(
        subtaskId: subtaskId,
        endedAt: DateTime.now(),
      );
    });
  }

  Future<void> _runAction(
    Future<TrackingChangeResult> Function() action,
  ) async {
    if (state.isSaving) {
      return;
    }
    final int operationVersion = _beginOperation();
    state = const ItemActionState(isSaving: true, errorMessage: null);
    try {
      await action();
      if (!_canCommit(operationVersion)) {
        return;
      }
      state = const ItemActionState.idle();
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(operationVersion)) {
        return;
      }
      debugPrint('更新子任务失败：$error');
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
