/// 用户确认导出时选择的任务及日期范围。
class WorkTimeExportRequest {
  WorkTimeExportRequest({
    required List<String> taskIds,
    required this.startDate,
    required this.endDate,
  }) : taskIds = List<String>.unmodifiable(taskIds);

  final List<String> taskIds;
  final DateTime startDate;
  final DateTime endDate;
}
