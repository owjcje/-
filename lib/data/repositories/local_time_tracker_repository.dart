import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:work_time_tracker/data/services/local_database_service.dart';
import 'package:work_time_tracker/domain/entities/tracking_change_result.dart';
import 'package:work_time_tracker/domain/entities/work_data_event.dart';
import 'package:work_time_tracker/domain/entities/work_item_status.dart';
import 'package:work_time_tracker/domain/entities/work_subtask_summary.dart';
import 'package:work_time_tracker/domain/entities/work_task_summary.dart';
import 'package:work_time_tracker/domain/entities/work_time_export_task.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry_page.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';

/// 使用 SQLite 实现任务、子任务与计时记录的本地持久化。
class LocalTimeTrackerRepository implements TimeTrackerRepository {
  LocalTimeTrackerRepository._({required LocalDatabaseService databaseService})
      : _databaseService = databaseService;

  static final LocalTimeTrackerRepository instance =
      LocalTimeTrackerRepository._(
    databaseService: LocalDatabaseService.instance,
  );

  static const String _selectedTaskSettingKey = 'selected_task_id';
  final LocalDatabaseService _databaseService;
  final StreamController<WorkDataEvent> _changeController =
      StreamController<WorkDataEvent>.broadcast();

  @override
  Stream<WorkDataEvent> get changes => _changeController.stream;

  @override
  Future<void> initialize() async {
    await _databaseService.initialize();
  }

  @override
  Future<bool> hasTasks() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      'tasks',
      columns: <String>['id'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<String>> getTaskIds({
    required String query,
    required WorkItemStatus? status,
  }) async {
    final Database database = await _databaseService.database;
    final List<String> conditions = <String>[];
    final List<Object?> arguments = <Object?>[];
    _addSearchCondition(conditions, arguments, query);
    _addStatusCondition(conditions, arguments, status);
    final List<Map<String, Object?>> rows = await database.query(
      'tasks',
      columns: <String>['id'],
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'sort_order ASC, created_at DESC, id DESC',
    );
    return rows
        .map((Map<String, Object?> row) => row['id']! as String)
        .toList(growable: false);
  }

  @override
  Future<WorkTaskSummary?> getTaskSummary(String taskId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      _taskSummarySql,
      <Object?>[taskId],
    );
    return rows.isEmpty ? null : _readTaskSummary(rows.first);
  }

  @override
  Future<List<WorkTaskSummary>> getExportableTaskSummaries() async {
    final List<String> taskIds = await getTaskIds(
      query: '',
      status: null,
    );
    final List<WorkTaskSummary> tasks = <WorkTaskSummary>[];
    for (final String taskId in taskIds) {
      final WorkTaskSummary? task = await getTaskSummary(taskId);
      if (task != null) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  @override
  Future<List<WorkTimeExportTask>> getWorkTimeExportTasks({
    required List<String> taskIds,
    required DateTime rangeStartAt,
    required DateTime rangeEndAt,
  }) async {
    if (taskIds.isEmpty) {
      return <WorkTimeExportTask>[];
    }
    final Database database = await _databaseService.database;
    final int rangeStartTimestamp = _toTimestamp(rangeStartAt);
    final int rangeEndTimestamp = _toTimestamp(rangeEndAt);
    final List<WorkTimeExportTask> tasks = <WorkTimeExportTask>[];
    for (final String taskId in taskIds) {
      final List<Map<String, Object?>> rows = await database.rawQuery(
        _workTimeExportSql,
        <Object?>[
          rangeStartTimestamp,
          rangeEndTimestamp,
          rangeEndTimestamp,
          rangeEndTimestamp,
          rangeEndTimestamp,
          rangeStartTimestamp,
          rangeEndTimestamp,
          rangeEndTimestamp,
          rangeStartTimestamp,
          taskId,
        ],
      );
      if (rows.isNotEmpty) {
        tasks.add(_readWorkTimeExportTask(rows));
      }
    }
    return tasks;
  }

  @override
  Future<String> createTask({
    required String title,
    required int colorValue,
    required WorkItemStatus status,
    required DateTime createdAt,
  }) async {
    final Database database = await _databaseService.database;
    final String taskId = 'task_${createdAt.microsecondsSinceEpoch}';
    final int sortOrder = await _getNextSortOrder(database, 'tasks');
    await database.insert('tasks', <String, Object?>{
      'id': taskId,
      'title': title,
      'color_value': colorValue,
      'status': status.name,
      'created_at': _toTimestamp(createdAt),
      'sort_order': sortOrder,
    });
    _changeController.add(TaskCreatedEvent(taskId: taskId));
    return taskId;
  }

  @override
  Future<void> updateTaskTitle({
    required String taskId,
    required String title,
  }) async {
    final Database database = await _databaseService.database;
    await database.update(
      'tasks',
      <String, Object?>{'title': title},
      where: 'id = ?',
      whereArgs: <Object?>[taskId],
    );
    _changeController.add(
      WorkItemsChangedEvent(
        taskIds: <String>{taskId},
        subtaskIds: <String>{},
        shouldRefreshTimeEntries: false,
      ),
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      await transaction.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: <Object?>[taskId],
      );
      await transaction.delete(
        'app_settings',
        where: 'setting_key = ? AND setting_value = ?',
        whereArgs: <Object?>[_selectedTaskSettingKey, taskId],
      );
    });
    _changeController.add(TaskDeletedEvent(taskId: taskId));
  }

  @override
  Future<void> reorderTasks(List<String> taskIds) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      final Batch batch = transaction.batch();
      for (int i = 0; i < taskIds.length; i += 1) {
        batch.update(
          'tasks',
          <String, Object?>{'sort_order': i},
          where: 'id = ?',
          whereArgs: <Object?>[taskIds[i]],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<TrackingChangeResult> updateTaskStatus({
    required String taskId,
    required WorkItemStatus status,
    required DateTime changedAt,
  }) async {
    final Database database = await _databaseService.database;
    final TrackingChangeResult result =
        await database.transaction((Transaction transaction) async {
      // 运行状态与任务状态保持一致，离开“进行中”时先固定结束时间。
      final Set<String> subtaskIds = status != WorkItemStatus.inProgress
          ? await _stopTaskTracking(transaction, taskId, changedAt)
          : <String>{};
      await transaction.update(
        'tasks',
        <String, Object?>{'status': status.name},
        where: 'id = ?',
        whereArgs: <Object?>[taskId],
      );
      return TrackingChangeResult(
        taskIds: <String>{taskId},
        subtaskIds: subtaskIds,
      );
    });
    _publishItemsChanged(result);
    return result;
  }

  @override
  Future<List<String>> getSubtaskIds({
    required String taskId,
    required String query,
    required WorkItemStatus? status,
  }) async {
    final Database database = await _databaseService.database;
    final List<String> conditions = <String>['task_id = ?'];
    final List<Object?> arguments = <Object?>[taskId];
    _addSearchCondition(conditions, arguments, query);
    _addStatusCondition(conditions, arguments, status);
    final List<Map<String, Object?>> rows = await database.query(
      'subtasks',
      columns: <String>['id'],
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'sort_order ASC, created_at DESC, id DESC',
    );
    return rows
        .map((Map<String, Object?> row) => row['id']! as String)
        .toList(growable: false);
  }

  @override
  Future<WorkSubtaskSummary?> getSubtaskSummary(String subtaskId) async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.rawQuery(
      _subtaskSummarySql,
      <Object?>[subtaskId],
    );
    return rows.isEmpty ? null : _readSubtaskSummary(rows.first);
  }

  @override
  Future<String> createSubtask({
    required String taskId,
    required String title,
    required WorkItemStatus status,
    required DateTime createdAt,
  }) async {
    final Database database = await _databaseService.database;
    final String subtaskId = 'subtask_${createdAt.microsecondsSinceEpoch}';
    final int sortOrder = await _getNextSortOrder(
      database,
      'subtasks',
      where: 'task_id = ?',
      whereArgs: <Object?>[taskId],
    );
    await database.insert('subtasks', <String, Object?>{
      'id': subtaskId,
      'task_id': taskId,
      'title': title,
      'note': '',
      'status': status.name,
      'created_at': _toTimestamp(createdAt),
      'sort_order': sortOrder,
    });
    _changeController.add(
      SubtaskCreatedEvent(taskId: taskId, subtaskId: subtaskId),
    );
    return subtaskId;
  }

  @override
  Future<void> updateSubtaskTitle({
    required String subtaskId,
    required String title,
  }) async {
    final Database database = await _databaseService.database;
    final String taskId = await _getTaskId(database, subtaskId);
    await database.update(
      'subtasks',
      <String, Object?>{'title': title},
      where: 'id = ?',
      whereArgs: <Object?>[subtaskId],
    );
    _changeController.add(
      WorkItemsChangedEvent(
        taskIds: <String>{taskId},
        subtaskIds: <String>{subtaskId},
        shouldRefreshTimeEntries: false,
      ),
    );
  }

  @override
  Future<void> updateSubtaskNote({
    required String subtaskId,
    required String note,
  }) async {
    final Database database = await _databaseService.database;
    final String taskId = await _getTaskId(database, subtaskId);
    await database.update(
      'subtasks',
      <String, Object?>{'note': note},
      where: 'id = ?',
      whereArgs: <Object?>[subtaskId],
    );
    _changeController.add(
      WorkItemsChangedEvent(
        taskIds: <String>{taskId},
        subtaskIds: <String>{subtaskId},
        shouldRefreshTimeEntries: false,
      ),
    );
  }

  @override
  Future<void> deleteSubtask(String subtaskId) async {
    final Database database = await _databaseService.database;
    final String taskId = await _getTaskId(database, subtaskId);
    await database.delete(
      'subtasks',
      where: 'id = ?',
      whereArgs: <Object?>[subtaskId],
    );
    _changeController.add(
      SubtaskDeletedEvent(taskId: taskId, subtaskId: subtaskId),
    );
  }

  @override
  Future<void> reorderSubtasks({
    required String taskId,
    required List<String> subtaskIds,
  }) async {
    final Database database = await _databaseService.database;
    await database.transaction((Transaction transaction) async {
      final Batch batch = transaction.batch();
      for (int i = 0; i < subtaskIds.length; i += 1) {
        batch.update(
          'subtasks',
          <String, Object?>{'sort_order': i},
          where: 'id = ? AND task_id = ?',
          whereArgs: <Object?>[subtaskIds[i], taskId],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<TrackingChangeResult> updateSubtaskStatus({
    required String subtaskId,
    required WorkItemStatus status,
    required DateTime changedAt,
  }) async {
    final Database database = await _databaseService.database;
    final TrackingChangeResult result =
        await database.transaction((Transaction transaction) async {
      final String taskId = await _getTaskId(transaction, subtaskId);
      // 子任务不再处于“进行中”时，先结束当前计时记录。
      if (status != WorkItemStatus.inProgress) {
        await _stopSubtaskEntry(transaction, subtaskId, changedAt);
      }
      await transaction.update(
        'subtasks',
        <String, Object?>{'status': status.name},
        where: 'id = ?',
        whereArgs: <Object?>[subtaskId],
      );
      return TrackingChangeResult(
        taskIds: <String>{taskId},
        subtaskIds: <String>{subtaskId},
      );
    });
    _publishItemsChanged(result);
    return result;
  }

  @override
  Future<TrackingChangeResult> startTracking({
    required String subtaskId,
    required DateTime startedAt,
  }) async {
    final Database database = await _databaseService.database;
    final TrackingChangeResult result =
        await database.transaction((Transaction transaction) async {
      final Map<String, Object?> target = await _getSubtaskRow(
        transaction,
        subtaskId,
      );
      if (target['status'] == WorkItemStatus.completed.name) {
        throw StateError('已完成的子任务不能开始计时。');
      }
      final Set<String> taskIds = <String>{target['task_id']! as String};
      final Set<String> subtaskIds = <String>{subtaskId};
      await _stopCurrentEntry(
        transaction,
        startedAt,
        taskIds,
        subtaskIds,
      );
      await _insertRunningEntry(transaction, subtaskId, startedAt);
      await _markTrackingInProgress(transaction, target);
      return TrackingChangeResult(taskIds: taskIds, subtaskIds: subtaskIds);
    });
    _publishItemsChanged(result);
    return result;
  }

  @override
  Future<TrackingChangeResult> stopTracking({
    required String subtaskId,
    required DateTime endedAt,
  }) async {
    final Database database = await _databaseService.database;
    final TrackingChangeResult result =
        await database.transaction((Transaction transaction) async {
      final String taskId = await _getTaskId(transaction, subtaskId);
      await _stopSubtaskEntry(transaction, subtaskId, endedAt);
      return TrackingChangeResult(
        taskIds: <String>{taskId},
        subtaskIds: <String>{subtaskId},
      );
    });
    _publishItemsChanged(result);
    return result;
  }

  void _publishItemsChanged(TrackingChangeResult result) {
    _changeController.add(
      WorkItemsChangedEvent(
        taskIds: result.taskIds,
        subtaskIds: result.subtaskIds,
        shouldRefreshTimeEntries: true,
      ),
    );
  }

  @override
  Future<WorkTimeEntryPage> getTimeEntries({
    required String subtaskId,
    required int pageSize,
    DateTime? beforeStartedAt,
    String? beforeId,
  }) async {
    final Database database = await _databaseService.database;
    final List<String> conditions = <String>['subtask_id = ?'];
    final List<Object?> arguments = <Object?>[subtaskId];
    _addCursorCondition(
      conditions,
      arguments,
      beforeStartedAt,
      beforeId,
    );
    final List<Map<String, Object?>> rows = await database.query(
      'time_entries',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'started_at DESC, id DESC',
      limit: pageSize + 1,
    );
    final bool hasMore = rows.length > pageSize;
    final Iterable<Map<String, Object?>> pageRows = rows.take(pageSize);
    return WorkTimeEntryPage(
      entries: pageRows.map(_readTimeEntry).toList(growable: false),
      hasMore: hasMore,
    );
  }

  @override
  Future<void> updateTimeEntry({
    required String entryId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    if (!endedAt.isAfter(startedAt)) {
      throw ArgumentError.value(endedAt, 'endedAt', '结束时间必须晚于开始时间。');
    }
    final Database database = await _databaseService.database;
    final TrackingChangeResult result =
        await database.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> rows = await transaction.rawQuery(
        'SELECT e.subtask_id, s.task_id FROM time_entries e '
        'JOIN subtasks s ON s.id = e.subtask_id WHERE e.id = ?',
        <Object?>[entryId],
      );
      if (rows.isEmpty) {
        throw StateError('未找到指定计时记录。');
      }
      final Map<String, Object?> entry = rows.first;
      await transaction.update(
        'time_entries',
        <String, Object?>{
          'started_at': _toTimestamp(startedAt),
          'ended_at': _toTimestamp(endedAt),
        },
        where: 'id = ?',
        whereArgs: <Object?>[entryId],
      );
      return TrackingChangeResult(
        taskIds: <String>{entry['task_id']! as String},
        subtaskIds: <String>{entry['subtask_id']! as String},
      );
    });
    _publishItemsChanged(result);
  }

  @override
  Future<String?> getSelectedTaskId() async {
    final Database database = await _databaseService.database;
    final List<Map<String, Object?>> rows = await database.query(
      'app_settings',
      columns: <String>['setting_value'],
      where: 'setting_key = ?',
      whereArgs: <Object?>[_selectedTaskSettingKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['setting_value'] as String?;
  }

  @override
  Future<void> saveSelectedTaskId(String? taskId) async {
    final Database database = await _databaseService.database;
    if (taskId == null) {
      await database.delete(
        'app_settings',
        where: 'setting_key = ?',
        whereArgs: <Object?>[_selectedTaskSettingKey],
      );
      return;
    }
    await database.insert(
      'app_settings',
      <String, Object?>{
        'setting_key': _selectedTaskSettingKey,
        'setting_value': taskId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 新建条目放在当前列表首位，后续拖动会把顺序重新规整为连续值。
  Future<int> _getNextSortOrder(
    DatabaseExecutor executor,
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final String whereClause = where == null ? '' : ' WHERE $where';
    final List<Map<String, Object?>> rows = await executor.rawQuery(
      'SELECT COALESCE(MIN(sort_order), 0) - 1 AS next_order '
      'FROM $table$whereClause',
      whereArgs,
    );
    return rows.first['next_order']! as int;
  }

  Future<Set<String>> _stopTaskTracking(
    Transaction transaction,
    String taskId,
    DateTime endedAt,
  ) async {
    final List<Map<String, Object?>> rows = await transaction.rawQuery(
      'SELECT e.id, e.subtask_id FROM time_entries e '
      'JOIN subtasks s ON s.id = e.subtask_id '
      'WHERE s.task_id = ? AND e.ended_at IS NULL',
      <Object?>[taskId],
    );
    if (rows.isEmpty) {
      return <String>{};
    }
    await transaction.update(
      'time_entries',
      <String, Object?>{'ended_at': _toTimestamp(endedAt)},
      where: 'id = ?',
      whereArgs: <Object?>[rows.first['id']],
    );
    return <String>{rows.first['subtask_id']! as String};
  }

  Future<void> _stopCurrentEntry(
    Transaction transaction,
    DateTime endedAt,
    Set<String> taskIds,
    Set<String> subtaskIds,
  ) async {
    final List<Map<String, Object?>> rows = await transaction.rawQuery(
      'SELECT e.id, e.subtask_id, s.task_id FROM time_entries e '
      'JOIN subtasks s ON s.id = e.subtask_id '
      'WHERE e.ended_at IS NULL LIMIT 1',
    );
    if (rows.isEmpty) {
      return;
    }
    final Map<String, Object?> row = rows.first;
    await transaction.update(
      'time_entries',
      <String, Object?>{'ended_at': _toTimestamp(endedAt)},
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
    taskIds.add(row['task_id']! as String);
    subtaskIds.add(row['subtask_id']! as String);
  }

  Future<void> _insertRunningEntry(
    Transaction transaction,
    String subtaskId,
    DateTime startedAt,
  ) async {
    await transaction.insert('time_entries', <String, Object?>{
      'id': '${subtaskId}_${startedAt.microsecondsSinceEpoch}',
      'subtask_id': subtaskId,
      'started_at': _toTimestamp(startedAt),
      'ended_at': null,
    });
  }

  Future<void> _markTrackingInProgress(
    Transaction transaction,
    Map<String, Object?> target,
  ) async {
    await transaction.update(
      'subtasks',
      <String, Object?>{'status': WorkItemStatus.inProgress.name},
      where: 'id = ?',
      whereArgs: <Object?>[target['id']],
    );
    await transaction.update(
      'tasks',
      <String, Object?>{'status': WorkItemStatus.inProgress.name},
      where: 'id = ?',
      whereArgs: <Object?>[target['task_id']],
    );
  }

  Future<void> _stopSubtaskEntry(
    Transaction transaction,
    String subtaskId,
    DateTime endedAt,
  ) async {
    await transaction.update(
      'time_entries',
      <String, Object?>{'ended_at': _toTimestamp(endedAt)},
      where: 'subtask_id = ? AND ended_at IS NULL',
      whereArgs: <Object?>[subtaskId],
    );
  }

  Future<String> _getTaskId(
    DatabaseExecutor executor,
    String subtaskId,
  ) async {
    final Map<String, Object?> row = await _getSubtaskRow(
      executor,
      subtaskId,
    );
    return row['task_id']! as String;
  }

  Future<Map<String, Object?>> _getSubtaskRow(
    DatabaseExecutor executor,
    String subtaskId,
  ) async {
    final List<Map<String, Object?>> rows = await executor.query(
      'subtasks',
      columns: <String>['id', 'task_id', 'status'],
      where: 'id = ?',
      whereArgs: <Object?>[subtaskId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('未找到指定子任务。');
    }
    return rows.first;
  }

  static void _addSearchCondition(
    List<String> conditions,
    List<Object?> arguments,
    String query,
  ) {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }
    conditions.add("title LIKE ? ESCAPE '\\'");
    arguments.add('%${_escapeLike(normalizedQuery)}%');
  }

  static void _addStatusCondition(
    List<String> conditions,
    List<Object?> arguments,
    WorkItemStatus? status,
  ) {
    if (status == null) {
      return;
    }
    conditions.add('status = ?');
    arguments.add(status.name);
  }

  static void _addCursorCondition(
    List<String> conditions,
    List<Object?> arguments,
    DateTime? beforeStartedAt,
    String? beforeId,
  ) {
    if (beforeStartedAt == null || beforeId == null) {
      return;
    }
    final int timestamp = _toTimestamp(beforeStartedAt);
    conditions.add('(started_at < ? OR (started_at = ? AND id < ?))');
    arguments.addAll(<Object?>[timestamp, timestamp, beforeId]);
  }

  static String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  static WorkTaskSummary _readTaskSummary(Map<String, Object?> row) {
    return WorkTaskSummary(
      id: row['id']! as String,
      title: row['title']! as String,
      colorValue: row['color_value']! as int,
      status: _statusFromDatabase(row['status']! as String),
      createdAt: _fromTimestamp(row['created_at']! as int),
      completedSeconds: row['completed_seconds']! as int,
      subtaskCount: row['subtask_count']! as int,
      trackedSubtaskCount: row['tracked_subtask_count']! as int,
      hasRunningSubtask: (row['has_running_subtask']! as int) == 1,
    );
  }

  static WorkSubtaskSummary _readSubtaskSummary(
    Map<String, Object?> row,
  ) {
    return WorkSubtaskSummary(
      id: row['id']! as String,
      taskId: row['task_id']! as String,
      title: row['title']! as String,
      note: row['note']! as String,
      status: _statusFromDatabase(row['status']! as String),
      createdAt: _fromTimestamp(row['created_at']! as int),
      completedSeconds: row['completed_seconds']! as int,
      isRunning: (row['is_running']! as int) == 1,
      timeEntryCount: row['time_entry_count']! as int,
      lastStartedAt: _readOptionalTimestamp(row['last_started_at']),
      lastEndedAt: _readOptionalTimestamp(row['last_ended_at']),
    );
  }

  static WorkTimeEntry _readTimeEntry(Map<String, Object?> row) {
    return WorkTimeEntry(
      id: row['id']! as String,
      subtaskId: row['subtask_id']! as String,
      startedAt: _fromTimestamp(row['started_at']! as int),
      endedAt: _readOptionalTimestamp(row['ended_at']),
    );
  }

  static WorkTimeExportTask _readWorkTimeExportTask(
    List<Map<String, Object?>> rows,
  ) {
    final Map<String, Object?> taskRow = rows.first;
    final List<WorkTimeExportSubtask> subtasks = <WorkTimeExportSubtask>[];
    final List<Map<String, Object?>> currentSubtaskRows =
        <Map<String, Object?>>[];
    String? currentSubtaskId;
    for (final Map<String, Object?> row in rows) {
      final Object? subtaskId = row['subtask_id'];
      if (subtaskId == null) {
        continue;
      }
      final String nextSubtaskId = subtaskId as String;
      if (currentSubtaskId != null && currentSubtaskId != nextSubtaskId) {
        subtasks.add(_readWorkTimeExportSubtask(currentSubtaskRows));
        currentSubtaskRows.clear();
      }
      currentSubtaskId = nextSubtaskId;
      currentSubtaskRows.add(row);
    }
    if (currentSubtaskRows.isNotEmpty) {
      subtasks.add(_readWorkTimeExportSubtask(currentSubtaskRows));
    }
    return WorkTimeExportTask(
      id: taskRow['task_id']! as String,
      title: taskRow['task_title']! as String,
      completedSeconds: subtasks.fold<int>(
        0,
        (int total, WorkTimeExportSubtask subtask) =>
            total + subtask.completedSeconds,
      ),
      subtasks: subtasks,
    );
  }

  static WorkTimeExportSubtask _readWorkTimeExportSubtask(
    List<Map<String, Object?>> rows,
  ) {
    final Map<String, Object?> subtaskRow = rows.first;
    final List<WorkTimeExportEntry> entries = <WorkTimeExportEntry>[];
    for (final Map<String, Object?> row in rows) {
      final Object? entryId = row['entry_id'];
      if (entryId == null) {
        continue;
      }
      entries.add(
        WorkTimeExportEntry(
          id: entryId as String,
          startedAt: _readOptionalTimestamp(row['entry_started_at']),
          endedAt: _readOptionalTimestamp(row['entry_ended_at']),
          completedSeconds: row['entry_seconds']! as int,
        ),
      );
    }
    return WorkTimeExportSubtask(
      id: subtaskRow['subtask_id']! as String,
      title: subtaskRow['subtask_title']! as String,
      note: subtaskRow['subtask_note']! as String,
      completedSeconds: entries.fold<int>(
        0,
        (int total, WorkTimeExportEntry entry) =>
            total + entry.completedSeconds,
      ),
      firstStartedAt: entries.isEmpty ? null : entries.first.startedAt,
      lastEndedAt: entries.isEmpty ? null : entries.last.endedAt,
      entries: entries,
    );
  }

  static WorkItemStatus _statusFromDatabase(String value) {
    return switch (value) {
      'inProgress' => WorkItemStatus.inProgress,
      'notStarted' => WorkItemStatus.notStarted,
      'completed' => WorkItemStatus.completed,
      _ => throw FormatException('无法识别的任务状态：$value'),
    };
  }

  static int _toTimestamp(DateTime dateTime) {
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

  static DateTime _fromTimestamp(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    ).toLocal();
  }

  static DateTime? _readOptionalTimestamp(Object? value) {
    return value == null ? null : _fromTimestamp(value as int);
  }

  static const String _taskSummarySql = '''
    SELECT
      t.id,
      t.title,
      t.color_value,
      t.status,
      t.created_at,
      (SELECT COUNT(*) FROM subtasks s WHERE s.task_id = t.id)
        AS subtask_count,
      (SELECT COUNT(*) FROM subtasks s WHERE s.task_id = t.id AND EXISTS (
        SELECT 1 FROM time_entries e
        WHERE e.subtask_id = s.id AND e.ended_at IS NOT NULL
      )) AS tracked_subtask_count,
      COALESCE((SELECT CAST(SUM(e.ended_at - e.started_at) / 1000 AS INTEGER)
        FROM time_entries e
        JOIN subtasks s ON s.id = e.subtask_id
        WHERE s.task_id = t.id AND e.ended_at IS NOT NULL), 0)
        AS completed_seconds,
      EXISTS(SELECT 1 FROM time_entries e
        JOIN subtasks s ON s.id = e.subtask_id
        WHERE s.task_id = t.id AND e.ended_at IS NULL)
        AS has_running_subtask
    FROM tasks t
    WHERE t.id = ?
  ''';

  static const String _subtaskSummarySql = '''
    SELECT
      s.id,
      s.task_id,
      s.title,
      s.note,
      s.status,
      s.created_at,
      COUNT(e.id) AS time_entry_count,
      COALESCE(CAST(SUM(CASE WHEN e.ended_at IS NOT NULL
        THEN e.ended_at - e.started_at ELSE 0 END) / 1000 AS INTEGER), 0)
        AS completed_seconds,
      MAX(CASE WHEN e.id IS NOT NULL AND e.ended_at IS NULL
        THEN 1 ELSE 0 END) AS is_running,
      MAX(e.started_at) AS last_started_at,
      MAX(e.ended_at) AS last_ended_at
    FROM subtasks s
    LEFT JOIN time_entries e ON e.subtask_id = s.id
    WHERE s.id = ?
    GROUP BY s.id
  ''';

  static const String _workTimeExportSql = '''
    SELECT
      t.id AS task_id,
      t.title AS task_title,
      s.id AS subtask_id,
      s.title AS subtask_title,
      s.note AS subtask_note,
      e.id AS entry_id,
      CASE WHEN e.id IS NULL THEN NULL ELSE MAX(e.started_at, ?) END
        AS entry_started_at,
      CASE WHEN e.id IS NULL THEN NULL
        ELSE MIN(COALESCE(e.ended_at, ?), ?) END AS entry_ended_at,
      COALESCE(CAST(CASE WHEN e.id IS NULL THEN 0
        ELSE MIN(COALESCE(e.ended_at, ?), ?) - MAX(e.started_at, ?) END / 1000 AS INTEGER), 0)
        AS entry_seconds
    FROM tasks t
    LEFT JOIN subtasks s ON s.task_id = t.id
    LEFT JOIN time_entries e ON e.subtask_id = s.id
      AND e.started_at < ?
      AND COALESCE(e.ended_at, ?) > ?
    WHERE t.id = ?
    ORDER BY s.sort_order ASC, s.created_at DESC, s.id DESC,
      e.started_at ASC, e.id ASC
  ''';
}
