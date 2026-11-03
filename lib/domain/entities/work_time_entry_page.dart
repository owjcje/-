import 'package:work_time_tracker/domain/entities/work_time_entry.dart';

/// 计时记录的游标分页结果。
class WorkTimeEntryPage {
  WorkTimeEntryPage({
    required List<WorkTimeEntry> entries,
    required this.hasMore,
  }) : entries = List<WorkTimeEntry>.unmodifiable(entries);

  final List<WorkTimeEntry> entries;
  final bool hasMore;
}
