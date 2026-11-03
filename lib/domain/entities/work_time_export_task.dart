/// Excel 导出所需的主任务及其子任务工时数据。
class WorkTimeExportTask {
  WorkTimeExportTask({
    required this.id,
    required this.title,
    required this.completedSeconds,
    required List<WorkTimeExportSubtask> subtasks,
  }) : subtasks = List<WorkTimeExportSubtask>.unmodifiable(subtasks);

  final String id;
  final String title;
  final int completedSeconds;
  final List<WorkTimeExportSubtask> subtasks;
}

/// Excel 导出所需的单个子任务汇总数据。
class WorkTimeExportSubtask {
  WorkTimeExportSubtask({
    required this.id,
    required this.title,
    required this.note,
    required this.completedSeconds,
    required this.firstStartedAt,
    required this.lastEndedAt,
    required List<WorkTimeExportEntry> entries,
  }) : entries = List<WorkTimeExportEntry>.unmodifiable(entries);

  final String id;
  final String title;
  final String note;
  final int completedSeconds;
  final DateTime? firstStartedAt;
  final DateTime? lastEndedAt;
  final List<WorkTimeExportEntry> entries;
}

/// Excel 导出所需的一段独立计时记录。
class WorkTimeExportEntry {
  const WorkTimeExportEntry({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.completedSeconds,
  });

  final String id;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int completedSeconds;
}
