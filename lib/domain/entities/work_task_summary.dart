import 'package:work_time_tracker/domain/entities/work_item_status.dart';

/// 主任务列表和概览需要的聚合数据，包含子任务与累计工时统计。
class WorkTaskSummary {
  const WorkTaskSummary({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.status,
    required this.createdAt,
    required this.completedSeconds,
    required this.subtaskCount,
    required this.trackedSubtaskCount,
    required this.hasRunningSubtask,
  });

  final String id;
  final String title;
  final int colorValue;
  final WorkItemStatus status;
  final DateTime createdAt;
  final int completedSeconds;
  final int subtaskCount;
  final int trackedSubtaskCount;
  final bool hasRunningSubtask;
}
