import 'package:work_time_tracker/domain/entities/work_item_status.dart';

/// 主任务基础实体，保存名称、颜色、状态与创建时间。
class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final int colorValue;
  final WorkItemStatus status;
  final DateTime createdAt;
}
