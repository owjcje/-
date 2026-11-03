import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 修改已保存计时记录的起止时间，并阻止写入无效时间范围。
class UpdateTimeEntryUseCase {
  factory UpdateTimeEntryUseCase({required TimeTrackerRepository repository}) {
    return UpdateTimeEntryUseCase._(repository: repository);
  }

  UpdateTimeEntryUseCase._({required TimeTrackerRepository repository})
      : _repository = repository;

  final TimeTrackerRepository _repository;

  Future<void> execute({
    required String entryId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    if (!endedAt.isAfter(startedAt)) {
      throw ArgumentError.value(endedAt, 'endedAt', '结束时间必须晚于开始时间。');
    }
    await _repository.updateTimeEntry(
      entryId: entryId,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }
}
