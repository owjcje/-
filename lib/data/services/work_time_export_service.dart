import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:work_time_tracker/domain/entities/work_time_export_task.dart';

/// 负责将已聚合的工时数据写入 Excel，并交由系统选择保存位置。
class WorkTimeExportService {
  WorkTimeExportService._();

  static final WorkTimeExportService instance = WorkTimeExportService._();

  Future<String?> export({
    required List<WorkTimeExportTask> tasks,
    required WorkTimeExportLabels labels,
  }) async {
    final DateTime exportedAt = DateTime.now();
    final Excel excel = Excel.createExcel();
    excel.rename('Sheet1', labels.summarySheetName);
    final Sheet summarySheet = excel[labels.summarySheetName];
    final Sheet detailSheet = excel[labels.detailSheetName];
    _writeSummarySheet(summarySheet, tasks, labels);
    _writeDetailSheet(detailSheet, tasks, labels);
    final List<int>? bytes = excel.save();
    if (bytes == null) {
      throw StateError('无法生成 Excel 文件。');
    }
    final String fileName = _buildFileName(exportedAt, labels.fileNamePrefix);
    final FileSaveLocation? saveLocation = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: labels.excelFileTypeLabel,
          extensions: <String>['xlsx'],
        ),
      ],
    );
    if (saveLocation == null) {
      return null;
    }
    final XFile exportFile = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: fileName,
    );
    await exportFile.saveTo(saveLocation.path);
    return saveLocation.path;
  }

  void _writeSummarySheet(
    Sheet sheet,
    List<WorkTimeExportTask> tasks,
    WorkTimeExportLabels labels,
  ) {
    _writeHeader(sheet, <String>[
      labels.taskColumn,
      labels.totalDurationColumn,
      labels.subtaskCountColumn,
    ]);
    for (final WorkTimeExportTask task in tasks) {
      sheet.appendRow(<CellValue>[
        TextCellValue(task.title),
        TextCellValue(_buildDurationText(task.completedSeconds)),
        IntCellValue(task.subtasks.length),
      ]);
    }
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 14);
  }

  void _writeDetailSheet(
    Sheet sheet,
    List<WorkTimeExportTask> tasks,
    WorkTimeExportLabels labels,
  ) {
    _writeHeader(sheet, <String>[
      labels.taskColumn,
      labels.subtaskColumn,
      labels.subtaskNoteColumn,
      labels.subtaskDurationColumn,
      labels.entryNumberColumn,
      labels.entryDurationColumn,
      labels.firstStartedAtColumn,
      labels.lastEndedAtColumn,
    ]);
    for (final WorkTimeExportTask task in tasks) {
      if (task.subtasks.isEmpty) {
        sheet.appendRow(<CellValue>[
          TextCellValue(task.title),
          TextCellValue(labels.emptyValue),
          TextCellValue(labels.emptyValue),
          TextCellValue('00:00:00'),
          TextCellValue(labels.emptyValue),
          TextCellValue('00:00:00'),
          TextCellValue(labels.emptyValue),
          TextCellValue(labels.emptyValue),
        ]);
        continue;
      }
      for (final WorkTimeExportSubtask subtask in task.subtasks) {
        _writeSubtaskEntries(sheet, task, subtask, labels);
      }
    }
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 40);
    sheet.setColumnWidth(3, 26);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 22);
    sheet.setColumnWidth(7, 22);
  }

  void _writeSubtaskEntries(
    Sheet sheet,
    WorkTimeExportTask task,
    WorkTimeExportSubtask subtask,
    WorkTimeExportLabels labels,
  ) {
    if (subtask.entries.isEmpty) {
      sheet.appendRow(<CellValue>[
        TextCellValue(task.title),
        TextCellValue(subtask.title),
        TextCellValue(subtask.note),
        TextCellValue(_buildDurationText(subtask.completedSeconds)),
        TextCellValue(labels.emptyValue),
        TextCellValue('00:00:00'),
        TextCellValue(labels.emptyValue),
        TextCellValue(labels.emptyValue),
      ]);
      return;
    }
    for (int i = 0; i < subtask.entries.length; i += 1) {
      final WorkTimeExportEntry entry = subtask.entries[i];
      sheet.appendRow(<CellValue>[
        TextCellValue(task.title),
        TextCellValue(subtask.title),
        TextCellValue(subtask.note),
        TextCellValue(_buildDurationText(subtask.completedSeconds)),
        IntCellValue(i + 1),
        TextCellValue(_buildDurationText(entry.completedSeconds)),
        _buildDateTimeCellValue(entry.startedAt, labels.emptyValue),
        _buildDateTimeCellValue(entry.endedAt, labels.emptyValue),
      ]);
    }
  }

  void _writeHeader(Sheet sheet, List<String> headers) {
    const List<String> columnNames = <String>[
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
    ];
    final CellStyle headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (int i = 0; i < headers.length; i += 1) {
      sheet.updateCell(
        CellIndex.indexByString('${columnNames[i]}1'),
        TextCellValue(headers[i]),
        cellStyle: headerStyle,
      );
    }
  }

  CellValue _buildDateTimeCellValue(DateTime? dateTime, String emptyValue) {
    if (dateTime == null) {
      return TextCellValue(emptyValue);
    }
    return DateTimeCellValue(
      year: dateTime.year,
      month: dateTime.month,
      day: dateTime.day,
      hour: dateTime.hour,
      minute: dateTime.minute,
      second: dateTime.second,
    );
  }

  String _buildFileName(DateTime exportedAt, String fileNamePrefix) {
    final String month = exportedAt.month.toString().padLeft(2, '0');
    final String day = exportedAt.day.toString().padLeft(2, '0');
    final String hour = exportedAt.hour.toString().padLeft(2, '0');
    final String minute = exportedAt.minute.toString().padLeft(2, '0');
    final String second = exportedAt.second.toString().padLeft(2, '0');
    return '${fileNamePrefix}_${exportedAt.year}$month${day}_$hour$minute$second.xlsx';
  }

  String _buildDurationText(int totalSeconds) {
    final int safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final int hours = safeSeconds ~/ 3600;
    final int minutes = (safeSeconds % 3600) ~/ 60;
    final int seconds = safeSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

/// 承载 Excel 工作表及列标题的本地化文案。
class WorkTimeExportLabels {
  const WorkTimeExportLabels({
    required this.summarySheetName,
    required this.detailSheetName,
    required this.taskColumn,
    required this.totalDurationColumn,
    required this.subtaskCountColumn,
    required this.subtaskColumn,
    required this.subtaskNoteColumn,
    required this.subtaskDurationColumn,
    required this.entryNumberColumn,
    required this.entryDurationColumn,
    required this.firstStartedAtColumn,
    required this.lastEndedAtColumn,
    required this.excelFileTypeLabel,
    required this.fileNamePrefix,
    required this.emptyValue,
  });

  final String summarySheetName;
  final String detailSheetName;
  final String taskColumn;
  final String totalDurationColumn;
  final String subtaskCountColumn;
  final String subtaskColumn;
  final String subtaskNoteColumn;
  final String subtaskDurationColumn;
  final String entryNumberColumn;
  final String entryDurationColumn;
  final String firstStartedAtColumn;
  final String lastEndedAtColumn;
  final String excelFileTypeLabel;
  final String fileNamePrefix;
  final String emptyValue;
}
