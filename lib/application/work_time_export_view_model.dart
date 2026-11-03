import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/item_action_state.dart';
import 'package:work_time_tracker/data/services/work_time_export_service.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/domain/entities/work_time_export_task.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 协调导出数据读取、Excel 生成和保存结果反馈。
class WorkTimeExportViewModel extends StateNotifier<ItemActionState> {
  WorkTimeExportViewModel({
    required TimeTrackerRepository repository,
    required WorkTimeExportService exportService,
  })  : _repository = repository,
        _exportService = exportService,
        super(const ItemActionState.idle());

  final TimeTrackerRepository _repository;
  final WorkTimeExportService _exportService;

  Future<List<WorkTaskSummary>> loadTaskOptions() async {
    try {
      return await _repository.getExportableTaskSummaries();
    } on Object catch (error, stackTrace) {
      debugPrint('加载可导出主任务失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        state = ItemActionState(isSaving: false, errorMessage: '$error');
      }
      return <WorkTaskSummary>[];
    }
  }

  Future<String?> export({
    required List<String> taskIds,
    required DateTime startDate,
    required DateTime endDate,
    required WorkTimeExportLabels labels,
  }) async {
    if (state.isSaving || taskIds.isEmpty || endDate.isBefore(startDate)) {
      return null;
    }
    state = const ItemActionState(isSaving: true, errorMessage: null);
    try {
      final DateTime rangeStartAt = _buildStartAt(startDate);
      final DateTime rangeEndAt = _buildEffectiveEndAt(endDate);
      final List<WorkTimeExportTask> tasks =
          await _repository.getWorkTimeExportTasks(
        taskIds: taskIds,
        rangeStartAt: rangeStartAt,
        rangeEndAt: rangeEndAt,
      );
      final String? savedPath = await _exportService.export(
        tasks: tasks,
        labels: labels,
      );
      if (mounted) {
        state = const ItemActionState.idle();
      }
      return savedPath;
    } on Object catch (error, stackTrace) {
      debugPrint('导出工时 Excel 失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        state = ItemActionState(isSaving: false, errorMessage: '$error');
      }
      return null;
    }
  }

  DateTime _buildStartAt(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _buildEffectiveEndAt(DateTime date) {
    final DateTime rangeEndAt = DateTime(date.year, date.month, date.day + 1);
    final DateTime now = DateTime.now();
    return rangeEndAt.isAfter(now) ? now : rangeEndAt;
  }
}
