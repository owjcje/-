import 'package:work_time_tracker/domain/entities/work_item_status.dart';

/// 子任务基础实体，通过 [taskId] 归属于一个主任务。
class WorkSubtask {
  const WorkSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String title;
  final String note;
  final WorkItemStatus status;
  final DateTime createdAt;
}
