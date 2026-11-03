import 'package:work_time_tracker/domain/entities/work_item_status.dart';

/// 将界面筛选项转换为 Repository 可识别的可选业务状态。
enum WorkStatusFilter {
  all,
  inProgress,
  notStarted,
  completed;

  WorkItemStatus? get status {
    return switch (this) {
      WorkStatusFilter.all => null,
      WorkStatusFilter.inProgress => WorkItemStatus.inProgress,
      WorkStatusFilter.notStarted => WorkItemStatus.notStarted,
      WorkStatusFilter.completed => WorkItemStatus.completed,
    };
  }
}
