import 'package:work_time_tracker/domain/entities/work_item_status.dart';

/// 子任务卡片需要的聚合数据，包含运行状态与最近计时时间。
class WorkSubtaskSummary {
  const WorkSubtaskSummary({
    required this.id,
    required this.taskId,
    required this.title,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.completedSeconds,
    required this.isRunning,
    required this.timeEntryCount,
    this.lastStartedAt,
    this.lastEndedAt,
  });

  final String id;
  final String taskId;
  final String title;
  final String note;
  final WorkItemStatus status;
  final DateTime createdAt;
  final int completedSeconds;
  final bool isRunning;
  final int timeEntryCount;
  final DateTime? lastStartedAt;
  final DateTime? lastEndedAt;
}
