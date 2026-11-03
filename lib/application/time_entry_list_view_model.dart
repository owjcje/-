import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:work_time_tracker/application/time_entry_list_state.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry.dart';
import 'package:work_time_tracker/domain/entities/work_time_entry_page.dart';
import 'package:work_time_tracker/domain/repositories/time_tracker_repository.dart';
import 'package:work_time_tracker/domain/use_cases/update_time_entry.dart';

/// 按游标分页加载单个子任务的计时明细，避免一次读取全部记录。
class TimeEntryListViewModel extends StateNotifier<TimeEntryListState> {
  TimeEntryListViewModel({
    required this.subtaskId,
    required TimeTrackerRepository repository,
    required UpdateTimeEntryUseCase updateTimeEntryUseCase,
  })  : _repository = repository,
        _updateTimeEntryUseCase = updateTimeEntryUseCase,
        super(TimeEntryListState.initial());

  static const int _pageSize = 50; // 单次只加载一页，限制明细内存和渲染数量
  final String subtaskId;
  final TimeTrackerRepository _repository;
  final UpdateTimeEntryUseCase _updateTimeEntryUseCase;
  int _requestVersion = 0;

  Future<void> initialize() async {
    final int requestVersion = _beginRequest();
    try {
      final WorkTimeEntryPage page = await _repository.getTimeEntries(
        subtaskId: subtaskId,
        pageSize: _pageSize,
      );
      if (!_canCommit(requestVersion)) {
        return;
      }
      state = TimeEntryListState(
        entries: page.entries,
        hasMore: page.hasMore,
        isLoading: false,
        isLoadingMore: false,
        errorMessage: null,
      );
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(requestVersion)) {
        return;
      }
      debugPrint('加载计时明细失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = TimeEntryListState(
        entries: <WorkTimeEntry>[],
        hasMore: false,
        isLoading: false,
        isLoadingMore: false,
        errorMessage: '$error',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.entries.isEmpty) {
      return;
    }
    final int requestVersion = _beginRequest();
    final List<WorkTimeEntry> currentEntries = state.entries;
    final bool currentHasMore = state.hasMore;
    final WorkTimeEntry lastEntry = currentEntries.last;
    state = TimeEntryListState(
      entries: currentEntries,
      hasMore: currentHasMore,
      isLoading: false,
      isLoadingMore: true,
      errorMessage: null,
    );
    try {
      final WorkTimeEntryPage page = await _repository.getTimeEntries(
        subtaskId: subtaskId,
        pageSize: _pageSize,
        beforeStartedAt: lastEntry.startedAt,
        beforeId: lastEntry.id,
      );
      if (!_canCommit(requestVersion)) {
        return;
      }
      state = TimeEntryListState(
        entries: <WorkTimeEntry>[...currentEntries, ...page.entries],
        hasMore: page.hasMore,
        isLoading: false,
        isLoadingMore: false,
        errorMessage: null,
      );
    } on Exception catch (error, stackTrace) {
      if (!_canCommit(requestVersion)) {
        return;
      }
      debugPrint('加载更多计时明细失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      state = TimeEntryListState(
        entries: currentEntries,
        hasMore: currentHasMore,
        isLoading: false,
        isLoadingMore: false,
        errorMessage: '$error',
      );
    }
  }

  Future<bool> updateEntryTime({
    required String entryId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    try {
      await _updateTimeEntryUseCase.execute(
        entryId: entryId,
        startedAt: startedAt,
        endedAt: endedAt,
      );
      return true;
    } on Object catch (error, stackTrace) {
      debugPrint('修改计时记录失败：$error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  int _beginRequest() {
    _requestVersion += 1;
    return _requestVersion;
  }

  bool _canCommit(int requestVersion) {
    return mounted && requestVersion == _requestVersion;
  }

  @override
  void dispose() {
    _requestVersion += 1;
    super.dispose();
  }
}
