import 'package:work_time_tracker/domain/entities/tracking_change_result.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 停止子任务计时的用例入口，统一结束时间的写入流程。
class StopSubtaskTrackingUseCase {
  factory StopSubtaskTrackingUseCase({
    required TimeTrackerRepository repository,
  }) {
    return StopSubtaskTrackingUseCase._(repository: repository);
  }

  StopSubtaskTrackingUseCase._({
    required TimeTrackerRepository repository,
  }) : _repository = repository;

  final TimeTrackerRepository _repository;

  Future<TrackingChangeResult> execute({
    required String subtaskId,
    required DateTime endedAt,
  }) {
    return _repository.stopTracking(
      subtaskId: subtaskId,
      endedAt: endedAt,
    );
  }
}
