import 'package:work_time_tracker/domain/entities/tracking_change_result.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 开始子任务计时的用例入口，隔离界面与数据实现。
class StartSubtaskTrackingUseCase {
  factory StartSubtaskTrackingUseCase({
    required TimeTrackerRepository repository,
  }) {
    return StartSubtaskTrackingUseCase._(repository: repository);
  }

  StartSubtaskTrackingUseCase._({
    required TimeTrackerRepository repository,
  }) : _repository = repository;

  final TimeTrackerRepository _repository;

  Future<TrackingChangeResult> execute({
    required String subtaskId,
    required DateTime startedAt,
  }) {
    return _repository.startTracking(
      subtaskId: subtaskId,
      startedAt: startedAt,
    );
  }
}
