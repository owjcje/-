import 'package:work_time_tracker/domain/entities/work_time_entry.dart';

/// 子任务计时明细分页列表的不可变界面状态。
class TimeEntryListState {
  TimeEntryListState({
    required List<WorkTimeEntry> entries,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    required this.errorMessage,
  }) : entries = List<WorkTimeEntry>.unmodifiable(entries);

  factory TimeEntryListState.initial() {
    return TimeEntryListState(
      entries: <WorkTimeEntry>[],
      hasMore: false,
      isLoading: true,
      isLoadingMore: false,
      errorMessage: null,
    );
  }

  final List<WorkTimeEntry> entries;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
}
