/// 计时操作完成后受影响的任务集合，用于精确刷新界面。
class TrackingChangeResult {
  TrackingChangeResult({
    required Set<String> taskIds,
    required Set<String> subtaskIds,
  })  : taskIds = Set<String>.unmodifiable(taskIds),
        subtaskIds = Set<String>.unmodifiable(subtaskIds);

  final Set<String> taskIds;
  final Set<String> subtaskIds;
}
