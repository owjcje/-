/// 单次计时记录；结束时间为空时表示仍在计时。
class WorkTimeEntry {
  const WorkTimeEntry({
    required this.id,
    required this.subtaskId,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final String subtaskId;
  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isRunning => endedAt == null;

  int? get completedSeconds {
    final DateTime? completedAt = endedAt;
    if (completedAt == null) {
      return null;
    }
    final int seconds = completedAt.difference(startedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }
}
