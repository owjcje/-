import 'package:work_time_tracker/domain/entities/tracking_change_result.dart';
import 'package:work_time_tracker/domain/entities/work_data_event.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/entities/work_subtask_summary.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/domain/entities/work_time_export_task.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry_page.dart';

/// 定义任务、子任务和计时数据的持久化边界。
abstract interface class TimeTrackerRepository {
  Stream<WorkDataEvent> get changes;

  Future<void> initialize();

  Future<bool> hasTasks();

  Future<List<String>> getTaskIds({
    required String query,
    required WorkItemStatus? status,
  });

  Future<WorkTaskSummary?> getTaskSummary(String taskId);

  Future<List<WorkTaskSummary>> getExportableTaskSummaries();

  Future<List<WorkTimeExportTask>> getWorkTimeExportTasks({
    required List<String> taskIds,
    required DateTime rangeStartAt,
    required DateTime rangeEndAt,
  });

  Future<String> createTask({
    required String title,
    required int colorValue,
    required WorkItemStatus status,
    required DateTime createdAt,
  });

  Future<void> updateTaskTitle({
    required String taskId,
    required String title,
  });

  Future<void> deleteTask(String taskId);

  Future<void> reorderTasks(List<String> taskIds);

  Future<TrackingChangeResult> updateTaskStatus({
    required String taskId,
    required WorkItemStatus status,
    required DateTime changedAt,
  });

  Future<List<String>> getSubtaskIds({
    required String taskId,
    required String query,
    required WorkItemStatus? status,
  });

  Future<WorkSubtaskSummary?> getSubtaskSummary(String subtaskId);

  Future<String> createSubtask({
    required String taskId,
    required String title,
    required WorkItemStatus status,
    required DateTime createdAt,
  });

  Future<void> updateSubtaskTitle({
    required String subtaskId,
    required String title,
  });

  Future<void> updateSubtaskNote({
    required String subtaskId,
    required String note,
  });

  Future<void> deleteSubtask(String subtaskId);

  Future<void> reorderSubtasks({
    required String taskId,
    required List<String> subtaskIds,
  });

  Future<TrackingChangeResult> updateSubtaskStatus({
    required String subtaskId,
    required WorkItemStatus status,
    required DateTime changedAt,
  });

  Future<TrackingChangeResult> startTracking({
    required String subtaskId,
    required DateTime startedAt,
  });

  Future<TrackingChangeResult> stopTracking({
    required String subtaskId,
    required DateTime endedAt,
  });

  Future<WorkTimeEntryPage> getTimeEntries({
    required String subtaskId,
    required int pageSize,
    DateTime? beforeStartedAt,
    String? beforeId,
  });

  Future<void> updateTimeEntry({
    required String entryId,
    required DateTime startedAt,
    required DateTime endedAt,
  });

  Future<String?> getSelectedTaskId();

  Future<void> saveSelectedTaskId(String? taskId);
}
