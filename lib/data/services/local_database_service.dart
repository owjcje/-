import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 负责创建、升级并复用本地 SQLite 数据库连接。
class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance = LocalDatabaseService._();
  static const int _databaseVersion = 4; // 数据库结构版本：第四版修复历史迁移状态不一致
  static const String _databaseFileName = 'work_time_tracker.db';

  Database? _database;

  Future<Database> get database async {
    final Database? currentDatabase = _database;
    if (currentDatabase != null) {
      return currentDatabase;
    }
    return initialize();
  }

  Future<Database> initialize() async {
    final Database? currentDatabase = _database;
    if (currentDatabase != null) {
      return currentDatabase;
    }
    try {
      sqfliteFfiInit();
      final Directory directory = await getApplicationSupportDirectory();
      final String databasePath = path.join(
        directory.path,
        _databaseFileName,
      );
      final Database openedDatabase = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onConfigure: _configureDatabase,
          onCreate: _createDatabase,
          onUpgrade: _upgradeDatabase,
        ),
      );
      _database = openedDatabase;
      return openedDatabase;
    } on Exception catch (error, stackTrace) {
      debugPrint('初始化本地工时数据库失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _configureDatabase(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
    await database.rawQuery('PRAGMA journal_mode = WAL');
    await database.execute('PRAGMA synchronous = FULL');
  }

  Future<void> _createDatabase(Database database, int version) async {
    await _createTaskTable(database);
    await _createSubtaskTable(database);
    await _createTimeEntryTable(database);
    await _createSettingTable(database);
    await _createIndexes(database);
  }

  /// 补齐历史数据库可能缺失的结构，保留用户已有的任务与计时数据。
  Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int _,
  ) async {
    if (oldVersion >= 4) {
      return;
    }
    // 第四版兼容历史库：版本号滞后时，字段可能已被之前的迁移添加。
    await _addWorkItemSortOrder(database);
    await _addSubtaskNote(database);
  }

  /// 为旧数据补充稳定顺序，迁移后仍保持原先“新建在前”的展示方式。
  Future<void> _addWorkItemSortOrder(Database database) async {
    final bool hasTaskSortOrder = await _hasColumn(
      database,
      'tasks',
      'sort_order',
    );
    if (!hasTaskSortOrder) {
      await database.execute(
        'ALTER TABLE tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await _initializeTaskSortOrder(database);
    }
    final bool hasSubtaskSortOrder = await _hasColumn(
      database,
      'subtasks',
      'sort_order',
    );
    if (!hasSubtaskSortOrder) {
      await database.execute(
        'ALTER TABLE subtasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
      await _initializeSubtaskSortOrder(database);
    }
    await _createWorkItemSortOrderIndexes(database);
  }

  Future<void> _initializeTaskSortOrder(Database database) async {
    await database.execute('''
      UPDATE tasks SET sort_order = (
        SELECT COUNT(*) FROM tasks newer
        WHERE newer.created_at > tasks.created_at
          OR (newer.created_at = tasks.created_at AND newer.id > tasks.id)
      )
    ''');
  }

  Future<void> _initializeSubtaskSortOrder(Database database) async {
    await database.execute('''
      UPDATE subtasks SET sort_order = (
        SELECT COUNT(*) FROM subtasks newer
        WHERE newer.task_id = subtasks.task_id
          AND (newer.created_at > subtasks.created_at
            OR (newer.created_at = subtasks.created_at
              AND newer.id > subtasks.id))
      )
    ''');
  }

  Future<void> _createWorkItemSortOrderIndexes(Database database) async {
    await database.execute(
      'CREATE INDEX IF NOT EXISTS index_tasks_sort_order ON tasks(sort_order)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS index_subtasks_task_sort_order '
      'ON subtasks(task_id, sort_order)',
    );
  }

  /// 为已有子任务补充可选备注，默认保留为空文本。
  Future<void> _addSubtaskNote(Database database) async {
    final bool hasSubtaskNote = await _hasColumn(database, 'subtasks', 'note');
    if (hasSubtaskNote) {
      return;
    }
    await database.execute(
      "ALTER TABLE subtasks ADD COLUMN note TEXT NOT NULL DEFAULT ''",
    );
  }

  Future<bool> _hasColumn(
    Database database,
    String tableName,
    String columnName,
  ) async {
    final List<Map<String, Object?>> columns = await database.rawQuery(
      'PRAGMA table_info($tableName)',
    );
    return columns.any(
      (Map<String, Object?> column) => column['name'] == columnName,
    );
  }

  Future<void> _createTaskTable(Database database) async {
    await database.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createSubtaskTable(Database database) async {
    await database.execute('''
      CREATE TABLE subtasks (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createTimeEntryTable(Database database) async {
    await database.execute('''
      CREATE TABLE time_entries (
        id TEXT PRIMARY KEY,
        subtask_id TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        CHECK (ended_at IS NULL OR ended_at >= started_at),
        FOREIGN KEY (subtask_id) REFERENCES subtasks(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createSettingTable(Database database) async {
    await database.execute('''
      CREATE TABLE app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT
      )
    ''');
  }

  Future<void> _createIndexes(Database database) async {
    await database.execute(
      'CREATE INDEX index_tasks_sort_order ON tasks(sort_order)',
    );
    await database.execute(
      'CREATE INDEX index_subtasks_task_sort_order '
      'ON subtasks(task_id, sort_order)',
    );
    await database.execute(
      'CREATE INDEX index_tasks_status_created '
      'ON tasks(status, created_at DESC)',
    );
    await database.execute(
      'CREATE INDEX index_subtasks_task_status_created '
      'ON subtasks(task_id, status, created_at DESC)',
    );
    await database.execute(
      'CREATE INDEX index_time_entries_subtask_started '
      'ON time_entries(subtask_id, started_at DESC, id DESC)',
    );
    await database.execute(
      'CREATE UNIQUE INDEX index_single_running_entry '
      'ON time_entries((1)) WHERE ended_at IS NULL',
    );
  }
}
